import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { AuthService } from '../auth.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly authService: AuthService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET || 'your-secret-key-change-in-production',
    });
  }

  async validate(payload: any) {
    console.log('🔐 JWT Strategy: Validating token for userId:', payload.sub);
    
    try {
      const user = await this.authService.validateUser(payload.sub);
      
      if (!user) {
        console.log('❌ JWT Strategy: User not found');
        throw new UnauthorizedException();
      }

      console.log('✅ JWT Strategy: User validated:', user.email);
      
      // Добавляем organizationId в request
      return {
        userId: user.id,
        email: user.email,
        organizationId: user.organizationId,
        role: user.role,
      };
    } catch (error) {
      console.log('❌ JWT Strategy: Validation error:', error.message);
      throw error;
    }
  }
}

