import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';
import { Organization } from '../organizations/entities/organization.entity';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import {
  normalizePhoneE164,
  phoneDigitsKey,
} from '../common/utils/phone.util';
import { UserRole } from '../common/enums/user-role.enum';

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
