import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { AuthService } from '../auth.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly authService: AuthService) {
    const secret = process.env.JWT_SECRET || 'Rtw+Dir1+3+AgjWFCOHJzQJng3FYhWXoNs5HUCkS23Q=';
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: secret,
      algorithms: ['HS256'],
    });
    console.log('🔐 JWT Strategy initialized with secret:', process.env.JWT_SECRET ? 'SET' : 'USING_FALLBACK');
  }

  async validate(payload: any) {
    console.log('🔐 JWT Strategy: Validating token');
    console.log('   Payload:', JSON.stringify(payload, null, 2));
    console.log('   UserId from token:', payload.sub);
    
    try {
      const user = await this.authService.validateUser(payload.sub);
      
      if (!user) {
        console.log('❌ JWT Strategy: User not found for ID:', payload.sub);
        throw new UnauthorizedException();
      }

      console.log('✅ JWT Strategy: User validated');
      console.log('   User ID:', user.id);
      console.log('   User email:', user.email);
      console.log('   User role:', user.role);
      console.log('   Organization ID:', user.organizationId);
      
      const result = {
        userId: user.id,
        email: user.email,
        organizationId: user.organizationId,
        role: user.role,
      };
      
      console.log('📤 JWT Strategy: Returning user data:', JSON.stringify(result, null, 2));
      
      // Добавляем organizationId в request
      return result;
    } catch (error) {
      console.log('❌ JWT Strategy: Validation error');
      console.log('   Error message:', error.message);
      console.log('   Error stack:', error.stack);
      throw error;
    }
  }
}

