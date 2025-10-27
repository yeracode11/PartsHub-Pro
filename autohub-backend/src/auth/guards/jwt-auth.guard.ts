import { Injectable, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest();
    const url = request.url.split('?')[0]; // Remove query params
    
    // Публичные эндпоинты - не требуют авторизации
    const publicRoutes = [
      '/api/auth/login',
      '/api/auth/refresh',
      '/api/b2c/parts',
      '/api/b2c/services',
      '/api/b2c/orders',
    ];
    
    if (publicRoutes.some(route => url.startsWith(route))) {
      console.log('🔓 Public route, skipping auth:', url);
      return true;
    }
    
    // Проверяем есть ли токен
    const authHeader = request.headers.authorization;
    if (!authHeader) {
      console.log('❌ JwtAuthGuard: No Authorization header');
      return false;
    }
    
    console.log('🔐 JwtAuthGuard: Checking request to:', url);
    console.log('🔐 JwtAuthGuard: Token present');
    
    // Вызываем родительский метод для проверки токена
    const result = super.canActivate(context);
    console.log('🔐 JwtAuthGuard: Result:', result);
    return result;
  }
}

