import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../../users/entities/user.entity';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET || 'Rtw+Dir1+3+AgjWFCOHJzQJng3FYhWXoNs5HUCkS23Q=',
      algorithms: ['HS256'],
    });
  }

  async validate(payload: any) {
    try {
      // Получаем пользователя напрямую из репозитория
      const user = await this.userRepository.findOne({
        where: { id: payload.sub },
        relations: ['organization'],
      });
      
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      if (!user.isActive) {
        throw new UnauthorizedException('User is inactive');
      }
      
      // Возвращаем данные пользователя для использования в @CurrentUser()
      // Важно: поле 'id' используется в контроллерах как user.id
      const result = {
        id: user.id, // Основной идентификатор для использования в контроллерах
        userId: user.id, // Дублируем для совместимости
        email: user.email,
        organizationId: user.organizationId,
        role: user.role,
      };

      return result;
    } catch (error) {
      throw error;
    }
  }
}

