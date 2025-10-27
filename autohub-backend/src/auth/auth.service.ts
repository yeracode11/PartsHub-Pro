import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/entities/user.entity';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly jwtService: JwtService,
  ) {}

  /**
   * Логин пользователя через email (упрощенная версия)
   */
  async login(loginDto: LoginDto) {
    try {
      console.log('🔐 Login attempt for email:', loginDto.email);
      
      // Ищем пользователя по email
      const user = await this.userRepository.findOne({
        where: { email: loginDto.email },
        relations: ['organization'],
      });

      if (!user) {
        console.log('❌ User not found for email:', loginDto.email);
        throw new UnauthorizedException(
          'Пользователь не зарегистрирован в системе',
        );
      }

      if (!user.isActive) {
        console.log('❌ User is inactive:', user.id);
        throw new UnauthorizedException('Пользователь деактивирован');
      }
      
      console.log('✅ User found:', user.id, 'with org:', user.organizationId);

      // Генерируем JWT токены
      const payload = {
        sub: user.id,
        email: user.email,
        organizationId: user.organizationId,
        role: user.role,
      };

      const accessToken = this.jwtService.sign(payload);
      const refreshToken = this.jwtService.sign(payload, { expiresIn: '30d' });

      console.log('✅ JWT tokens generated successfully');
      
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
    } catch (error) {
      console.error('❌ Login error:', error);
      throw new UnauthorizedException('Invalid credentials');
    }
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

