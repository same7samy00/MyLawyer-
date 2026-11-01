import dotenv from 'dotenv';
import path from 'path';

dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '4000', 10),
  host: process.env.HOST || '0.0.0.0',
  nodeEnv: process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL || 'postgresql://mylawyer_user:MyLawyer_SecurePass_2026!@127.0.0.1:5432/mylawyer_prod',
  jwtSecret: process.env.JWT_SECRET || 'super_secret_jwt_access_key_mylawyer_2026_prod_minimum_32_characters',
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET || 'super_secret_jwt_refresh_key_mylawyer_2026_prod_minimum_32_chars',
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

