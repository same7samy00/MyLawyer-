import nodemailer from 'nodemailer';
import { config } from '../config/index.js';
import { enqueue, handleJob } from './jobQueue.js';

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

/// The app's look for every email: its logo, its font (IBM Plex Sans Arabic) and its colours, right to left and centred.
/// Everything is inline and in tables, because Gmail and Outlook drop most page styles. Apple Mail and iPhone load
/// the app font; Gmail never loads outside fonts, so it shows the closest Arabic system font instead.
const LOGO_URL = 'https://my-lawyer.online/logo.png';
const FONT = "'IBM Plex Sans Arabic', 'Segoe UI', Tahoma, Arial, sans-serif";

/// A paragraph in the email, centred, in the app's text colour
export const emailText = (text: string, muted = false) =>
  `<p dir="rtl" style="margin:0 0 16px;font-family:${FONT};font-size:${muted ? 13 : 15}px;line-height:1.8;color:${muted ? '#64748B' : '#334155'};text-align:center;">${text}</p>`;

export function emailLayout(title: string, body: string): string {
  return `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;600;700&display=swap" rel="stylesheet">
</head>
<body dir="rtl" style="margin:0;padding:0;background:#F8FAFC;font-family:${FONT};">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="rtl" style="background:#F8FAFC;">
    <tr><td align="center" style="padding:24px 12px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="rtl" style="max-width:480px;background:#FFFFFF;border:1px solid #E2E8F0;border-radius:14px;">
        <tr><td align="center" style="padding:28px 24px 8px;">
          <img src="${LOGO_URL}" width="120" alt="My Lawyer" style="display:block;margin:0 auto;border:0;">
        </td></tr>
        <tr><td align="center" dir="rtl" style="padding:8px 24px 0;font-family:${FONT};font-size:19px;font-weight:700;color:#0F172A;text-align:center;">${title}</td></tr>
        <tr><td align="center" dir="rtl" style="padding:16px 24px 8px;text-align:center;">${body}</td></tr>
        <tr><td align="center" style="padding:14px 24px 22px;border-top:1px solid #E2E8F0;font-family:${FONT};font-size:12px;color:#64748B;text-align:center;">My Lawyer © ${new Date().getFullYear()}</td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

/// The code in a dashed box, the way the app shows codes
export const emailCode = (code: string) =>
  `<div style="margin:6px 0 18px;text-align:center;"><span dir="ltr" style="display:inline-block;background:#EFF6FF;border:2px dashed #1D4ED8;border-radius:7px;padding:14px 32px;font-family:${FONT};font-size:30px;font-weight:700;letter-spacing:8px;color:#1D4ED8;">${code}</span></div>`;

/// The code works 10 minutes, so an email still waiting after that is dropped
const OTP_MAX_AGE_MS = 10 * 60_000;

/// Sends the code through the queue, so a stopped worker or a busy mail server doesn't lose it
export async function sendOtpEmail(toEmail: string, otpCode: string, purpose: 'register' | 'reset_password') {
  await enqueue('otp-email', { toEmail, otpCode, purpose });
}

handleJob('otp-email', OTP_MAX_AGE_MS, ({ toEmail, otpCode, purpose }) => deliverOtpEmail(toEmail, otpCode, purpose));

async function deliverOtpEmail(toEmail: string, otpCode: string, purpose: 'register' | 'reset_password') {
  const mailer = getEmailTransporter();

  const title = purpose === 'register' ? 'تأكيد حسابك في My Lawyer' : 'تغيير كلمة السر في My Lawyer';
  const subtitle = purpose === 'register'
    ? 'أهلًا بيك في My Lawyer<br>اكتب الكود ده في التطبيق عشان نفعّل حسابك'
    : 'وصلنا طلب لتغيير كلمة السر بتاعة حسابك<br>اكتب الكود ده في التطبيق';

  const htmlContent = emailLayout(
    title,
    emailText(subtitle) + emailCode(otpCode) + emailText('الكود شغال 10 دقايق بس', true) + emailText('متدّيش الكود ده لأي حد<br>وفريق My Lawyer عمره ما هيطلبه منك', true)
  );

  // A failure throws, and the queue tries again
  const info = await mailer.sendMail({
    from: config.smtp.from,
    to: toEmail,
    // The inbox shows the app's name only, the code stays inside
    subject: 'My Lawyer',
    html: htmlContent,
    text: [title, subtitle.replace('<br>', '\n'), otpCode, 'الكود شغال 10 دقايق بس', 'متدّيش الكود ده لأي حد'].join('\n\n'),
  });
  console.log(`[Email] OTP sent to ${toEmail}. MessageId: ${info.messageId}`);
}
