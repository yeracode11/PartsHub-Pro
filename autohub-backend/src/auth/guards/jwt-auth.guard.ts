import {
  Injectable,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Observable } from 'rxjs';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const url = request.url.split('?')[0];

    const publicRoutes = [
      '/api/auth/login',
      '/api/auth/register',
      '/api/auth/refresh',
      '/api/b2c/parts',
      '/api/b2c/services',
      '/api/b2c/orders',
    ];

    if (publicRoutes.some((route) => url.startsWith(route))) {
      return true;
    }

    const authHeader = request.headers.authorization;
    if (!authHeader?.trim()) {
      throw new UnauthorizedException('Authorization header required');
    }

    try {
      const result = super.canActivate(context);

      let ok = false;
      if (result instanceof Observable) {
        ok = await firstValueFrom(result) === true;
      } else if (result instanceof Promise) {
        ok = (await result) === true;
      } else {
        ok = result === true;
      }

      if (!ok) {
        throw new UnauthorizedException('Invalid authentication');
      }

      return true;
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      throw new UnauthorizedException(
        error instanceof Error ? error.message : 'Invalid or expired token',
      );
    }
  }
}
