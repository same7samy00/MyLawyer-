import nodemailer from 'nodemailer';
import { config } from '../config/index.js';

let transporter: ReturnType<typeof nodemailer.createTransport> | null = null;

export function getEmailTransporter(): ReturnType<typeof nodemailer.createTransport> {
  if (!transporter) {
    const transportOptions: any = {
      host: config.smtp.host,
      port: config.smtp.port,
      secure: config.smtp.secure,
      tls: {
        rejectUnauthorized: false,
      },
    };

    if (config.smtp.user && config.smtp.pass) {
      transportOptions.auth = {
        user: config.smtp.user,
        pass: config.smtp.pass,
      };
    }

    transporter = nodemailer.createTransport(transportOptions);
  }
  return transporter as ReturnType<typeof nodemailer.createTransport>;
}

export async function sendOtpEmail(toEmail: string, otpCode: string, purpose: 'register' | 'reset_password'): Promise<boolean> {
  const mailer = getEmailTransporter();

  const title = purpose === 'register' ? 'تأكيد الحساب في تطبيق MyLawyer' : 'استعادة كلمة المرور في تطبيق MyLawyer';
  const subtitle = purpose === 'register' 
    ? 'شكراً لانضمامك إلى منصة MyLawyer. استخدم رمز التحقق التالي لتفعيل حسابك بأمان:' 
    : 'تلقينا طلباً لإعادة تعيين كلمة المرور الخاصة بحسابك في MyLawyer. استخدم الرمز التالي:';

  const htmlContent = `
    <!DOCTYPE html>
    <html lang="ar" dir="rtl">
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; text-align: right; }
        .card { max-width: 500px; margin: 0 auto; background: #ffffff; border-radius: 12px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
        .header { text-align: center; margin-bottom: 24px; }
        .brand { font-size: 28px; font-weight: 800; color: #1D4ED8; letter-spacing: -0.5px; }
        .title { font-size: 20px; font-weight: 700; color: #0f172a; margin-top: 16px; margin-bottom: 8px; }
        .text { font-size: 15px; color: #475569; line-height: 1.6; margin-bottom: 24px; }
        .otp-container { text-align: center; margin: 28px 0; }
        .otp-box { display: inline-block; background: #eff6ff; border: 2px dashed #3b82f6; border-radius: 8px; padding: 16px 36px; font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #1D4ED8; }
        .footer { text-align: center; font-size: 13px; color: #94a3b8; margin-top: 32px; border-top: 1px solid #e2e8f0; padding-top: 16px; }
        .badge { background: #fef3c7; color: #92400e; padding: 4px 12px; border-radius: 999px; font-size: 12px; font-weight: 600; display: inline-block; margin-top: 8px; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="header">
          <div class="brand">MyLawyer</div>
          <div class="title">${title}</div>
          <div class="badge">صالح لمدة 10 دقائق فقط</div>
        </div>
        <p class="text">${subtitle}</p>
        <div class="otp-container">
          <div class="otp-box">${otpCode}</div>
        </div>
        <p class="text" style="font-size: 13px; color: #64748b;">
          تنبيه أمني: لا تشارك هذا الرمز مع أي شخص، فريق MyLawyer لن يطلب منك أبداً رمز التحقق الخاص بك.
        </p>
        <div class="footer">
          © 2026 تطبيق MyLawyer. جميع الحقوق محفوظة.
        </div>
      </div>
    </body>
    </html>
  `;

  try {
    const info = await mailer.sendMail({
      from: config.smtp.from,
      to: toEmail,
      subject: `[MyLawyer] رمز التحقق الخاص بك: ${otpCode}`,
      html: htmlContent,
      text: `${title}\n\nرمز التحقق الخاص بك هو: ${otpCode}\n\nصالح لمدة 10 دقائق فقط. لا تشارك هذا الرمز مع أي شخص.`,
    });
    console.log(`[Email] OTP sent to ${toEmail}. MessageId: ${info.messageId}`);
    return true;
  } catch (err) {
    console.error(`[Email Error] Failed to send OTP email to ${toEmail}:`, err);
    return false;
  }
}
