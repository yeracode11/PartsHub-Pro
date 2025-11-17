import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';
import { CreateUserDto } from './dto/create-user.dto';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
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

  async findByOrganization(organizationId: string): Promise<User[]> {
    return await this.userRepository.find({
      where: { organizationId, isActive: true },
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

  // Создать или обновить пользователя после Firebase Auth
  async createOrUpdate(createDto: CreateUserDto): Promise<User> {
    const existing = await this.findByFirebaseUid(createDto.firebaseUid);
    
    if (existing) {
      // Обновляем существующего
      Object.assign(existing, {
        email: createDto.email,
        name: createDto.name,
      });
      return await this.userRepository.save(existing);
    }

    // Создаем нового
    return await this.create(createDto);
  }

  // Обновить профиль пользователя
  async updateProfile(userId: string, updateDto: { name?: string; email?: string }): Promise<User> {
    const user = await this.findOne(userId);
    
    if (updateDto.name !== undefined) {
      user.name = updateDto.name;
    }
    if (updateDto.email !== undefined) {
      user.email = updateDto.email;
    }
    
    const savedUser = await this.userRepository.save(user);
    
    // Загружаем с организацией для ответа
    return await this.findOne(savedUser.id);
  }
}
