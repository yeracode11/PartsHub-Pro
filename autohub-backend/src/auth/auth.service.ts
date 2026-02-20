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
    // Ищем пользователя по email
    const user = await this.userRepository.findOne({
      where: { email: loginDto.email },
      relations: ['organization'],
    });

    if (!user) {
      throw new UnauthorizedException('Неверный email или пароль');
    }

    if (!user.isActive) {
      throw new UnauthorizedException('Пользователь деактивирован');
    }

    // Проверяем пароль - обязательно должен быть
    if (!user.password) {
      throw new UnauthorizedException('Пароль не установлен. Обратитесь к администратору.');
    }

    const isPasswordValid = await bcrypt.compare(loginDto.password, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Неверный email или пароль');
    }

    // Генерируем JWT токены
    const payload = {
      sub: user.id,
      email: user.email,
      organizationId: user.organizationId,
      role: user.role,
    };

    const accessToken = this.jwtService.sign(payload);
    const refreshToken = this.jwtService.sign(payload, { expiresIn: '30d' });

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
    // Проверяем, не существует ли уже пользователь с таким email
    const existingUser = await this.userRepository.findOne({
      where: { email: registerDto.email },
    });

    if (existingUser) {
      throw new ConflictException('Пользователь с таким email уже существует');
    }

    // Создаем новую организацию
    const organizationName = registerDto.organizationName || `${registerDto.name} - Организация`;
    const businessType = (registerDto.businessType as BusinessType) || BusinessType.SERVICE;

    const organization = await this.organizationsService.create({
      name: organizationName,
      businessType: businessType,
      isActive: true,
    } as any);

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

    // Загружаем пользователя с организацией для ответа
    const userWithOrg = await this.userRepository.findOne({
      where: { id: savedUser.id },
      relations: ['organization'],
    });

    if (!userWithOrg) {
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

