import { Injectable, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Observable } from 'rxjs';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const url = request.url.split('?')[0]; // Remove query params

    // Публичные эндпоинты - не требуют авторизации
    const publicRoutes = [
      '/api/auth/login',
      '/api/auth/register',
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
      console.log('❌ JwtAuthGuard: No Authorization header for:', url);
      return false;
    }

    console.log('🔐 JwtAuthGuard: Checking request to:', url);
    console.log('🔐 JwtAuthGuard: Token present, calling Passport...');

    try {
      // Вызываем родительский метод для проверки токена
      const result = super.canActivate(context);
      
      // Обрабатываем результат (может быть boolean или Observable<boolean>)
      if (result instanceof Observable) {
        const value = await firstValueFrom(result);
        console.log('🔐 JwtAuthGuard: Observable result:', value);
        return value === true;
      } else if (result instanceof Promise) {
        const value = await result;
        console.log('🔐 JwtAuthGuard: Promise result:', value);
        return value === true;
      } else {
        console.log('🔐 JwtAuthGuard: Direct result:', result);
        return result === true;
      }
    } catch (error) {
      console.log('❌ JwtAuthGuard: Passport error:', error.message);
      console.log('❌ JwtAuthGuard: Error stack:', error.stack);
      return false;
    }
  }
}

