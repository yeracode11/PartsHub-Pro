import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { User } from './entities/user.entity';
import { Organization } from '../organizations/entities/organization.entity';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import {
  normalizePhoneE164,
  phoneDigitsKey,
} from '../common/utils/phone.util';
import { UserRole } from '../common/enums/user-role.enum';
import { CreateStaffDto } from './dto/create-staff.dto';

const SYNTHETIC_EMAIL_SUFFIX = '@phone.autohub.local';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Organization)
    private readonly organizationRepository: Repository<Organization>,
  ) {}

  async create(createDto: CreateUserDto): Promise<User> {
    const user = this.userRepository.create(createDto);
    return await this.userRepository.save(user);
  }

  async findByFirebaseUid(firebaseUid: string): Promise<User | null> {
    return await this.userRepository.findOne({
      where: { firebaseUid },
      relations: ['organization'],
    });
  }

  async findAll(): Promise<User[]> {
    return await this.userRepository.find({
      relations: ['organization'],
      order: { createdAt: 'DESC' },
    });
  }

  async findByOrganization(organizationId: string): Promise<User[]> {
    return await this.userRepository.find({
      where: { organizationId, isActive: true },
      relations: ['organization'],
    });
  }

  async findOne(id: string): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id },
      relations: ['organization'],
    });

    if (!user) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }

    return user;
  }

  async createOrUpdate(createDto: CreateUserDto): Promise<User> {
    const existing = await this.findByFirebaseUid(createDto.firebaseUid);

    if (existing) {
      Object.assign(existing, {
        email: createDto.email,
        name: createDto.name,
      });
      return await this.userRepository.save(existing);
    }

    return await this.create(createDto);
  }

  async listMasters(organizationId: string) {
    const users = await this.userRepository.find({
      where: {
        organizationId,
        role: In([UserRole.WORKER, UserRole.STO]),
        isActive: true,
      },
      order: { name: 'ASC' },
    });
    return users.map((user) => this.toStaffView(user));
  }

  async createMaster(organizationId: string, dto: CreateStaffDto) {
    const name = dto.name.trim();
    if (!name) {
      throw new BadRequestException('Укажите имя');
    }
    const phoneE164 = normalizePhoneE164(dto.phone);
    await this.assertPhoneAvailable(phoneE164, organizationId);

    const hashedPassword = await bcrypt.hash(dto.password, 10);
    const pay = this.normalizePay(dto.payType, dto.payRate);
    const user = this.userRepository.create({
      email: `${phoneDigitsKey(phoneE164)}${SYNTHETIC_EMAIL_SUFFIX}`,
      password: hashedPassword,
      name,
      phone: phoneE164,
      role: dto.role === 'sto' ? UserRole.STO : UserRole.WORKER,
      organizationId,
      isActive: true,
      payType: pay.payType,
      payRate: pay.payRate,
    });
    const saved = await this.userRepository.save(user);
    return this.toStaffView(saved);
  }

  async removeMaster(organizationId: string, userId: string) {
    const user = await this.userRepository.findOne({
      where: {
        id: userId,
        organizationId,
        role: In([UserRole.WORKER, UserRole.STO]),
      },
    });
    if (!user) {
      throw new NotFoundException('Мастер не найден');
    }
    user.isActive = false;
    await this.userRepository.save(user);
    return { success: true };
  }

  async updateMasterPay(
    organizationId: string,
    userId: string,
    payType?: string,
    payRate?: number,
  ) {
    const user = await this.userRepository.findOne({
      where: {
        id: userId,
        organizationId,
        role: UserRole.WORKER,
        isActive: true,
      },
    });
    if (!user) {
      throw new NotFoundException('Мастер не найден');
    }
    const pay = this.normalizePay(payType, payRate);
    user.payType = pay.payType;
    user.payRate = pay.payRate;
    const saved = await this.userRepository.save(user);
    return this.toStaffView(saved);
  }

  private toStaffView(user: User) {
    return {
      id: user.id,
      name: user.name,
      phone: user.phone,
      role: user.role,
      payType: user.payType === 'hourly' ? 'hourly' : 'percent',
      payRate: Number(user.payRate ?? 40),
    };
  }

  private normalizePay(payType?: string, payRate?: number) {
    const type = payType === 'hourly' ? 'hourly' : 'percent';
    let rate = Number(payRate);
    if (!Number.isFinite(rate)) {
      rate = type === 'hourly' ? 0 : 40;
    }
    if (type === 'percent') {
      rate = Math.min(100, Math.max(0, rate));
    } else {
      rate = Math.max(0, rate);
    }
    return { payType: type, payRate: Math.round(rate * 100) / 100 };
  }

  private async assertPhoneAvailable(
    phoneE164: string,
    organizationId: string,
  ): Promise<void> {
    const takenByUser = await this.userRepository.findOne({
      where: { phone: phoneE164, isActive: true },
    });
    if (takenByUser) {
      throw new ConflictException('Этот номер уже зарегистрирован');
    }

    const targetKey = phoneDigitsKey(phoneE164);
    const organizations = await this.organizationRepository.find({
      where: { isActive: true },
    });
    const orgConflict = organizations.find(
      (org) => org.phone && phoneDigitsKey(org.phone) === targetKey,
    );
    if (orgConflict && orgConflict.id !== organizationId) {
      throw new ConflictException('Этот номер уже используется другой организацией');
    }
    if (orgConflict && orgConflict.id === organizationId) {
      throw new ConflictException('Этот номер уже используется владельцем');
    }
  }

  async updateProfile(userId: string, updateDto: UpdateUserDto): Promise<User> {
    const user = await this.findOne(userId);

    if (updateDto.phone !== undefined) {
      await this.applyPhoneChange(user, updateDto.phone.trim());
    }

    if (updateDto.name !== undefined) {
      user.name = updateDto.name;
    }
    if (updateDto.email !== undefined) {
      user.email = updateDto.email;
    }

    const savedUser = await this.userRepository.save(user);

    return await this.findOne(savedUser.id);
  }

  private async applyPhoneChange(user: User, rawPhone: string): Promise<void> {
    let phoneE164: string;
    try {
      phoneE164 = normalizePhoneE164(rawPhone);
    } catch (e) {
      if (e instanceof BadRequestException) throw e;
      throw new BadRequestException('Введите корректный номер телефона');
    }

    if (user.phone === phoneE164) {
      return;
    }

    const takenByUser = await this.userRepository.findOne({
      where: { phone: phoneE164, isActive: true },
    });
    if (takenByUser && takenByUser.id !== user.id) {
      throw new ConflictException('Этот номер уже зарегистрирован');
    }

    const targetKey = phoneDigitsKey(phoneE164);
    const organizations = await this.organizationRepository.find({
      where: { isActive: true },
    });
    const orgConflict = organizations.find(
      (org) =>
        org.id !== user.organizationId &&
        org.phone &&
        phoneDigitsKey(org.phone) === targetKey,
    );
    if (orgConflict) {
      throw new ConflictException('Этот номер уже используется другой организацией');
    }

    user.phone = phoneE164;

    if (user.email.endsWith(SYNTHETIC_EMAIL_SUFFIX)) {
      user.email = `${phoneDigitsKey(phoneE164)}${SYNTHETIC_EMAIL_SUFFIX}`;
    }

    if (user.role === UserRole.OWNER) {
      await this.organizationRepository.update(user.organizationId, {
        phone: phoneE164,
      });
    }
  }
}
