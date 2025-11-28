import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '../../common/enums/user-role.enum';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    try {
      const request = context.switchToHttp().getRequest();
      const url = request.url.split('?')[0];
      
      const requiredRoles = this.reflector.getAllAndOverride<UserRole[]>('roles', [
        context.getHandler(),
        context.getClass(),
      ]);

      console.log(`🔐 RolesGuard: Checking ${url}`);
      console.log(`   Required roles:`, requiredRoles);

      // Если роли не указаны, разрешаем доступ всем авторизованным пользователям
      if (!requiredRoles || requiredRoles.length === 0) {
        console.log(`   ✅ No roles required, allowing access`);
        return true;
      }

      const { user } = request;
      
      // Проверяем, что пользователь существует
      if (!user) {
        console.error('❌ RolesGuard: User not found in request');
        throw new ForbiddenException('User not authenticated');
      }

      console.log(`   User role: ${user.role}`);

      // Проверяем, что у пользователя есть роль
      if (!user.role) {
        console.error('❌ RolesGuard: User role not found. User:', JSON.stringify(user));
        throw new ForbiddenException('User role not found');
      }

      // Проверяем, есть ли у пользователя одна из требуемых ролей
      const hasRole = requiredRoles.some((role) => user.role === role);
      
      if (!hasRole) {
        console.warn(`⚠️ RolesGuard: User role '${user.role}' not in required roles:`, requiredRoles);
        throw new ForbiddenException('Insufficient permissions');
      }

      console.log(`   ✅ Access granted for role: ${user.role}`);
      return true;
    } catch (error) {
      // Если это уже ForbiddenException, пробрасываем дальше
      if (error instanceof ForbiddenException) {
        throw error;
      }
      // Для других ошибок логируем и возвращаем 403
      console.error('❌ RolesGuard error:', error);
      throw new ForbiddenException('Access denied');
    }
  }
}

