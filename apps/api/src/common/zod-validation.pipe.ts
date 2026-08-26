import { BadRequestException, Injectable, PipeTransform } from '@nestjs/common';
import type { ZodType } from 'zod';

/**
 * Validates route bodies against a @renance/shared zod schema.
 * Usage:
 *   @Post('register')
 *   register(@Body(new ZodValidationPipe(registerRequestSchema)) dto: RegisterRequest)
 *
 * Single validation truth lives in shared — web/Flutter reuse the same
 * schemas later, so a rule change lands once everywhere.
 */
@Injectable()
export class ZodValidationPipe<T extends ZodType> implements PipeTransform<unknown, T['_output']> {
  constructor(private readonly schema: T) {}

  transform(value: unknown): T['_output'] {
    const result = this.schema.safeParse(value);
    if (!result.success) {
      throw new BadRequestException({
        message: 'validation failed',
        issues: result.error.flatten(),
      });
    }
    return result.data;
  }
}
