import { Injectable, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest();
    console.log('🔐 JwtAuthGuard: Checking request to:', request.url);
    console.log('🔐 JwtAuthGuard: Authorization header:', request.headers.authorization ? 'Present' : 'Missing');
    if (request.headers.authorization) {
      console.log('🔐 JwtAuthGuard: Token:', request.headers.authorization.substring(0, 30) + '...');
    }
    return super.canActivate(context);
  }
}

