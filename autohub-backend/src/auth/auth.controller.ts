import { Controller, Post, Body } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';

@Controller('api/auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  async login(@Body() loginDto: LoginDto) {
    console.log('🔐 AuthController: Login request for:', loginDto.email);
    try {
      const result = await this.authService.login(loginDto);
      console.log('✅ AuthController: Login successful');
      return result;
    } catch (error) {
      console.error('❌ AuthController: Login failed:', error);
      throw error;
    }
  }

  @Post('refresh')
  async refresh(@Body('refreshToken') refreshToken: string) {
    return this.authService.refreshToken(refreshToken);
  }
}

