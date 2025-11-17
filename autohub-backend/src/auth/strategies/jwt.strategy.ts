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
    
    console.log('🔐 JWT Strategy initialized');
    console.log('   Secret:', process.env.JWT_SECRET ? 'SET' : 'NOT SET (using fallback)');
  }

  async validate(payload: any) {
    console.log('🔐 JWT Strategy: Validating token');
    console.log('   Payload:', JSON.stringify(payload, null, 2));
    console.log('   UserId from token:', payload.sub);
    
    try {
      // Получаем пользователя напрямую из репозитория
      const user = await this.userRepository.findOne({
        where: { id: payload.sub },
        relations: ['organization'],
      });
      
      if (!user) {
        console.log('❌ JWT Strategy: User not found for ID:', payload.sub);
        throw new UnauthorizedException('User not found');
      }

      if (!user.isActive) {
        console.log('❌ JWT Strategy: User is inactive:', payload.sub);
        throw new UnauthorizedException('User is inactive');
      }

      console.log('✅ JWT Strategy: User validated');
      console.log('   User ID:', user.id);
      console.log('   User email:', user.email);
      console.log('   User role:', user.role);
      console.log('   Organization ID:', user.organizationId);
      
      // Возвращаем данные пользователя для использования в @CurrentUser()
      // Важно: поле 'id' используется в контроллерах как user.id
      const result = {
        id: user.id, // Основной идентификатор для использования в контроллерах
        userId: user.id, // Дублируем для совместимости
        email: user.email,
        organizationId: user.organizationId,
        role: user.role,
      };
      
      console.log('📤 JWT Strategy: Returning user data:', JSON.stringify(result, null, 2));
      
      return result;
    } catch (error) {
      console.log('❌ JWT Strategy: Validation error');
      console.log('   Error message:', error.message);
      console.log('   Error stack:', error.stack);
      throw error;
    }
  }
}

