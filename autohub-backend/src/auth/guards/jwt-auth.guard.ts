import { Injectable, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest();
    const url = request.url;
    
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
    
    console.log('🔐 JwtAuthGuard: Checking request to:', url);
    console.log('🔐 JwtAuthGuard: Authorization header:', request.headers.authorization ? 'Present' : 'Missing');
    if (request.headers.authorization) {
      console.log('🔐 JwtAuthGuard: Token:', request.headers.authorization.substring(0, 30) + '...');
    }
    
    return super.canActivate(context);
  }
}

