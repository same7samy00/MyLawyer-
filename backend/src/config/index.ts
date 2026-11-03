import dotenv from 'dotenv';
import path from 'path';

dotenv.config();

const MIN_SECRET_LENGTH = 32;

/// The repository is public, so anyone could forge a sign-in if production ran on a known secret
export function assertProductionSecrets(env: Record<string, string | undefined>) {
  if (env.NODE_ENV !== 'production') return;
  const secret = env.JWT_SECRET ?? '';
  if (secret.length < MIN_SECRET_LENGTH || secret.startsWith('super_secret_jwt')) {
    throw new Error(`JWT_SECRET must be a private value of at least ${MIN_SECRET_LENGTH} characters`);
  }
  if (!env.DATABASE_URL) throw new Error('DATABASE_URL is required');
}

assertProductionSecrets(process.env);

export const config = {
  port: parseInt(process.env.PORT || '4000', 10),
  host: process.env.HOST || '0.0.0.0',
  nodeEnv: process.env.NODE_ENV || 'development',
  // These two are for a local machine only, production refuses to start without its own
  databaseUrl: process.env.DATABASE_URL || 'postgresql://postgres:postgres@127.0.0.1:5432/mylawyer_dev',
  jwtSecret: process.env.JWT_SECRET || 'local-development-only-secret-never-used-in-production',
  publicStoragePath: process.env.PUBLIC_STORAGE_PATH || path.resolve(process.cwd(), 'storage/public'),
  privateStoragePath: process.env.PRIVATE_STORAGE_PATH || path.resolve(process.cwd(), 'storage/private_docs'),
  smtp: {
    host: process.env.SMTP_HOST || '127.0.0.1',
    port: parseInt(process.env.SMTP_PORT || '25', 10),
    secure: process.env.SMTP_SECURE === 'true',
    from: process.env.EMAIL_FROM || 'MyLawyer <noreply@masrypay.online>',
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  corsOrigin: process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : ['*'],
};

