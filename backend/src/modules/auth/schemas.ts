import { z } from 'zod';
import { isValidEgyptianPhone } from '../../utils/security.js';

export const registerSchema = z.object({
  phone: z.string().refine(isValidEgyptianPhone, {
    message: 'رقم الهاتف يجب أن يكون رقم مصري صحيح مكون من 11 خانة (مثال: 01012345678)'
  }),
  email: z.string().email({ message: 'البريد الإلكتروني غير صحيح' }).toLowerCase().trim(),
  password: z.string().min(8, { message: 'كلمة المرور يجب ألا تقل عن 8 أحرف وأرقام' }),
  confirmPassword: z.string(),
  role: z.enum(['client', 'lawyer'], { message: 'نوع الحساب يجب أن يكون client أو lawyer' }),
  fullName: z.string().optional(),
  syndicateNumber: z.string().optional(),
  experienceYears: z.number().int().min(0, { message: 'سنوات الخبرة غير صحيحة' }).max(70, { message: 'سنوات الخبرة غير صحيحة' }).optional(),
  agreeTerms: z.boolean().refine(val => val === true, { message: 'يجب الموافقة على الشروط والأحكام' })
}).refine(data => data.password === data.confirmPassword, {
  message: 'كلمة المرور وتأكيد كلمة المرور غير متطابقين',
  path: ['confirmPassword']
});

export const verifyOtpSchema = z.object({
  email: z.string().email(),
  otp: z.string().length(6, { message: 'رمز التحقق يجب أن يتكون من 6 أرقام' })
});

export const resendOtpSchema = z.object({
  email: z.string().email()
});

export const loginSchema = z.object({
  identifier: z.string().min(3, { message: 'أدخل رقم الهاتف أو البريد الإلكتروني' }).trim(),
  password: z.string().min(1, { message: 'أدخل كلمة المرور' }),
  rememberMe: z.boolean().optional(),
  // The control page's second step: the code sent by email after the password
  code: z.string().regex(/^\d{6}$/).optional()
});

export const forgotPasswordSchema = z.object({
  email: z.string().email({ message: 'البريد الإلكتروني غير صحيح' }).toLowerCase().trim()
});

export const resetPasswordSchema = z.object({
  email: z.string().email(),
  otp: z.string().length(6),
  newPassword: z.string().min(8, { message: 'كلمة المرور يجب ألا تقل عن 8 أحرف' }),
  confirmPassword: z.string()
}).refine(data => data.newPassword === data.confirmPassword, {
  message: 'كلمة المرور وتأكيدها غير متطابقين',
  path: ['confirmPassword']
});

