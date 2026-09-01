import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  check() {
    return {
      status: 'ok',
      service: 'renance-api',
      time: new Date().toISOString(),
      phases: { foundation: 'in-progress', core: 'next', cbt: 'after-core' },
    };
  }
}
