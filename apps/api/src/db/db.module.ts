import { Global, Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { createDb, type Db } from '@renance/db';

/** Injection token for the Drizzle client bundle ({ db, client }). */
export const DB = Symbol('RENANCE_DB');

/**
 * Global DB access module — every provider in the app may inject `DB`.
 * The client connects LAZILY (postgres.js opens sockets on first query),
 * so the api boots even before Neon credentials exist (great for CI).
 */
@Global()
@Module({
  imports: [ConfigModule],
  providers: [
    {
      provide: DB,
      inject: [ConfigService],
      useFactory: (config: ConfigService): Db => {
        const url = config.get<string>('DATABASE_URL');
        if (!url) {
          // Fail loudly and EARLY with a fix-it message instead of a cryptic
          // driver error on first request.
          throw new Error(
            'DATABASE_URL is not set. Copy .env.example to .env and paste your Neon pooled connection string.',
          );
        }
        return createDb(url);
      },
    },
  ],
  exports: [DB],
})
export class DbModule {}
