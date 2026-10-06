import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { normalizePhoneE164, phoneDigitsKey } from '../common/utils/phone.util';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from '../users/entities/user.entity';
import { Organization } from '../organizations/entities/organization.entity';
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
    @InjectRepository(Organization)
    private readonly organizationRepository: Repository<Organization>,
    private readonly jwtService: JwtService,
    private readonly organizationsService: OrganizationsService,
  ) {}

  /**
   * Логин по номеру телефона организации и паролю.
   */
  async login(loginDto: LoginDto) {
    let phoneE164: string;
    try {
      phoneE164 = normalizePhoneE164(loginDto.phone);
    } catch {
      throw new UnauthorizedException('Неверный телефон или пароль');
    }

    const user = await this.findUserByPhone(phoneE164);

    if (!user) {
      throw new UnauthorizedException('Неверный телефон или пароль');
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
      throw new UnauthorizedException('Неверный телефон или пароль');
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
        phone: user.phone,
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
   * Регистрация владельца: создаёт организацию. Мастера добавляет владелец в профиле.
   */
  async register(registerDto: RegisterDto) {
    let phoneE164: string;
    try {
      phoneE164 = normalizePhoneE164(registerDto.phone);
    } catch (e) {
      if (e instanceof BadRequestException) throw e;
      throw new BadRequestException('Введите корректный номер телефона');
    }

    const existingUser = await this.findUserByPhone(phoneE164);
    if (existingUser) {
      throw new ConflictException('Пользователь с таким телефоном уже зарегистрирован');
    }

    const displayName = registerDto.name.trim();
    const organizationName = registerDto.organizationName.trim();
    if (!displayName || !organizationName) {
      throw new BadRequestException('Укажите имя и название организации');
    }

    const businessType =
      (registerDto.businessType as BusinessType) || BusinessType.SERVICE;

    const organization = await this.organizationsService.create({
      name: organizationName,
      businessType,
      phone: phoneE164,
      isActive: true,
    } as any);

    const hashedPassword = await bcrypt.hash(registerDto.password, 10);
    const syntheticEmail = `${phoneDigitsKey(phoneE164)}@phone.autohub.local`;

    const user = this.userRepository.create({
      email: syntheticEmail,
      password: hashedPassword,
      name: displayName,
      phone: phoneE164,
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
        phone: userWithOrg.phone,
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

  /** Пользователь по личному телефону или телефону организации (владелец). */
  private async findUserByPhone(phoneE164: string): Promise<User | null> {
    const byUserPhone = await this.userRepository.findOne({
      where: { phone: phoneE164, isActive: true },
      relations: ['organization'],
    });

    if (byUserPhone) {
      return byUserPhone;
    }

    return this.findUserByOrganizationPhone(phoneE164);
  }

  /** Организация по телефону, с которым регистрировался владелец. */
  private async findOrganizationByPhone(phoneE164: string): Promise<Organization | null> {
    const exact = await this.organizationRepository.findOne({
      where: { phone: phoneE164, isActive: true },
    });
    if (exact) {
      return exact;
    }

    const targetKey = phoneDigitsKey(phoneE164);
    const organizations = await this.organizationRepository.find({
      where: { isActive: true },
    });
    return (
      organizations.find(
        (org) => org.phone && phoneDigitsKey(org.phone) === targetKey,
      ) ?? null
    );
  }

  /** Пользователь-владелец (или первый активный) по телефону организации. */
  private async findUserByOrganizationPhone(phoneE164: string): Promise<User | null> {
    const organization = await this.findOrganizationByPhone(phoneE164);

    if (!organization) {
      return null;
    }

    const owner = await this.userRepository.findOne({
      where: {
        organizationId: organization.id,
        role: UserRole.OWNER,
        isActive: true,
      },
      relations: ['organization'],
    });

    if (owner) {
      return owner;
    }

    return this.userRepository.findOne({
      where: { organizationId: organization.id, isActive: true },
      relations: ['organization'],
      order: { createdAt: 'ASC' },
    });
  }
}

