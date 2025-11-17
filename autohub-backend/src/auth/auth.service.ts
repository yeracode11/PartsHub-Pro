import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from '../users/entities/user.entity';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { OrganizationsService } from '../organizations/organizations.service';
import { BusinessType } from '../common/enums/business-type.enum';
import { UserRole } from '../common/enums/user-role.enum';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly jwtService: JwtService,
    private readonly organizationsService: OrganizationsService,
  ) {}

  /**
   * Логин пользователя через email (для Firebase auth)
   */
  async login(loginDto: LoginDto) {
    console.log('🔐 Login attempt for email:', loginDto.email);
    
    // Ищем пользователя по email
    const user = await this.userRepository.findOne({
      where: { email: loginDto.email },
      relations: ['organization'],
    });

    if (!user) {
      console.log('❌ User not found:', loginDto.email);
      throw new UnauthorizedException('Неверный email или пароль');
    }

    if (!user.isActive) {
      console.log('❌ User inactive:', user.id);
      throw new UnauthorizedException('Пользователь деактивирован');
    }

    // Проверяем пароль - обязательно должен быть
    if (!user.password) {
      console.log('❌ User has no password set:', user.id);
      throw new UnauthorizedException('Пароль не установлен. Обратитесь к администратору.');
    }

    const isPasswordValid = await bcrypt.compare(loginDto.password, user.password);
    if (!isPasswordValid) {
      console.log('❌ Invalid password for user:', user.id);
      throw new UnauthorizedException('Неверный email или пароль');
    }

    console.log('✅ User authenticated:', user.id);

    // Генерируем JWT токены
    const payload = {
      sub: user.id,
      email: user.email,
      organizationId: user.organizationId,
      role: user.role,
    };

    console.log('🔐 Generating JWT with payload:', JSON.stringify(payload));
    console.log('🔐 JWT_SECRET from env:', process.env.JWT_SECRET ? 'SET' : 'NOT SET');
    
    const accessToken = this.jwtService.sign(payload);
    const refreshToken = this.jwtService.sign(payload, { expiresIn: '30d' });
    
    console.log('✅ Generated accessToken:', accessToken.substring(0, 50) + '...');

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        organizationId: user.organizationId,
        organization: user.organization,
      },
    };
  }

  /**
   * Обновление access token через refresh token
   */
  async refreshToken(refreshToken: string) {
    try {
      const payload = this.jwtService.verify(refreshToken);

      const user = await this.userRepository.findOne({
        where: { id: payload.sub },
        relations: ['organization'],
      });

      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      const newPayload = {
        sub: user.id,
        email: user.email,
        organizationId: user.organizationId,
        role: user.role,
      };

      const accessToken = this.jwtService.sign(newPayload);

      return {
        accessToken,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
          organizationId: user.organizationId,
          organization: user.organization,
        },
      };
    } catch (error) {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  /**
   * Регистрация нового пользователя с созданием организации
   */
  async register(registerDto: RegisterDto) {
    console.log('📝 Registration attempt for email:', registerDto.email);

    // Проверяем, не существует ли уже пользователь с таким email
    const existingUser = await this.userRepository.findOne({
      where: { email: registerDto.email },
    });

    if (existingUser) {
      console.log('❌ User already exists:', registerDto.email);
      throw new ConflictException('Пользователь с таким email уже существует');
    }

    // Создаем новую организацию
    const organizationName = registerDto.organizationName || `${registerDto.name} - Организация`;
    const businessType = (registerDto.businessType as BusinessType) || BusinessType.SERVICE;

    console.log('🏢 Creating organization:', organizationName);
    const organization = await this.organizationsService.create({
      name: organizationName,
      businessType: businessType,
      isActive: true,
    } as any);

    console.log('✅ Organization created:', organization.id);

    // Хешируем пароль
    const hashedPassword = await bcrypt.hash(registerDto.password, 10);

    // Создаем пользователя с ролью owner
    const user = this.userRepository.create({
      email: registerDto.email,
      password: hashedPassword,
      name: registerDto.name,
      role: UserRole.OWNER,
      organizationId: organization.id,
      isActive: true,
    });

    const savedUser = await this.userRepository.save(user);
    console.log('✅ User created:', savedUser.id);

    // Загружаем пользователя с организацией для ответа
    const userWithOrg = await this.userRepository.findOne({
      where: { id: savedUser.id },
      relations: ['organization'],
    });

    if (!userWithOrg) {
      console.error('❌ User not found after creation:', savedUser.id);
      throw new Error('Ошибка при создании пользователя');
    }

    // Генерируем JWT токены
    const payload = {
      sub: userWithOrg.id,
      email: userWithOrg.email,
      organizationId: userWithOrg.organizationId,
      role: userWithOrg.role,
    };

    const accessToken = this.jwtService.sign(payload);
    const refreshToken = this.jwtService.sign(payload, { expiresIn: '30d' });

    console.log('✅ Registration successful for:', registerDto.email);

    return {
      accessToken,
      refreshToken,
      user: {
        id: userWithOrg.id,
        email: userWithOrg.email,
        name: userWithOrg.name,
        role: userWithOrg.role,
        organizationId: userWithOrg.organizationId,
        organization: userWithOrg.organization,
      },
    };
  }

  /**
   * Валидация пользователя по ID (используется в JWT Strategy)
   */
  async validateUser(userId: string): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: ['organization'],
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException();
    }

    return user;
  }
}

