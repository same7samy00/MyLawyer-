const AMOUNT_STEP = { key: 'amount', type: 'number', label: 'كم المبلغ بالجنيه؟' };
const REASON_STEP = { key: 'reason', type: 'text', label: 'ما السبب؟', min: 5 };

/// One action at a time: pick it, answer its steps, review, then run it
function openActionWindow(actions) {
  let action = null;
  let index = 0;
  let values = {};
  const close = () => { $('dialog').hidden = true; $('dialog').replaceChildren(); };
  const stepsNow = () => action.steps.filter((step) => !step.when || step.when(values));

  const frame = (title, stepText, bodyNodes, footNodes) => {
    const backdrop = el('div', undefined, 'modal-backdrop');
    const card = el('div', undefined, 'modal-card modal-md');
    const head = el('div', undefined, 'modal-header');
    const titleBox = el('div', undefined, 'modal-title-box');
    titleBox.append(el('h3', title));
    if (stepText) titleBox.append(el('span', stepText, 'wizard-step'));
    head.append(titleBox, closeIcon(close));
    const body = el('div', undefined, 'modal-body dialog-form');
    body.append(...bodyNodes);
    const foot = el('div', undefined, 'modal-actions');
    foot.append(...footNodes);
    card.append(head, body, foot);
    backdrop.append(card);
    $('dialog').replaceChildren(backdrop);
    $('dialog').hidden = false;
  };
  const stepLabel = () => 'الخطوة ' + (index + 2) + ' من ' + (stepsNow().length + (action.noReview ? 1 : 2));
  const back = () => {
    if (index > 0) index -= 1;
    else { action = null; values = {}; }
    draw();
  };
  const next = () => { index += 1; draw(); };

  const execute = async (errorNode, trigger) => {
    trigger.disabled = true;
    trigger.classList.add('is-loading');
    try {
      await action.run(values);
      const { success } = action;
      close();
      toast(success);
      navCountsAt = 0;
      await render();
    } catch (err) {
      errorNode.textContent = err.message;
      trigger.disabled = false;
      trigger.classList.remove('is-loading');
    }
  };

  const drawPicker = () => {
    const list = el('div', undefined, 'wizard-list');
    actions.forEach((item) => {
      const row = el('button', undefined, 'wizard-row');
      row.type = 'button';
      const match = ACTION_ICONS.find(([pattern]) => pattern.test(item.title));
      const glyph = el('span', undefined, 'action-icon ' + (match ? match[2] : 'tone-blue'));
      glyph.append(icon(match ? match[1] : 'ticket'));
      const text = el('span', undefined, 'wizard-row-text');
      text.append(el('strong', item.title), el('small', item.description));
      row.append(glyph, text);
      row.addEventListener('click', () => { action = item; index = 0; values = {}; draw(); });
      list.append(row);
    });
    frame('اتخاذ إجراء', 'اختر الإجراء', [list], []);
  };

  const drawStep = (step) => {
    const error = el('p', '', 'text-danger');
    if (step.type === 'choice') {
      const list = el('div', undefined, 'wizard-list');
      step.options.forEach(([value, label]) => {
        const row = el('button', label, 'wizard-choice' + (values[step.key] === value ? ' active' : ''));
        row.type = 'button';
        row.addEventListener('click', () => { values[step.key] = value; next(); });
        list.append(row);
      });
      frame(action.title, stepLabel(), [el('label', step.label, 'wizard-label'), list], [link('رجوع', back)]);
      return;
    }
    const field = step.type === 'long' ? textarea(values[step.key] || '', step.placeholder || '') : input(values[step.key] || '', step.placeholder || '');
    if (step.type === 'number') { field.type = 'number'; field.min = '0'; }
    const submit = () => {
      const value = field.value.trim();
      if (step.type === 'number' && !(Number(value) > 0)) { error.textContent = 'أدخل مبلغًا صحيحًا'; return; }
      if (!step.optional && step.type !== 'number' && value.length < (step.min || 1)) {
        error.textContent = step.min ? 'اكتب ' + step.min + ' أحرف على الأقل' : 'هذه الخانة مطلوبة';
        return;
      }
      values[step.key] = value;
      if (action.noReview && index === stepsNow().length - 1) { execute(error, nextButton); return; }
      next();
    };
    const isLast = action.noReview && index === stepsNow().length - 1;
    const nextButton = link(isLast ? 'حفظ' : 'التالي', submit, 'btn-primary');
    if (step.type !== 'long') field.addEventListener('keydown', (event) => { if (event.key === 'Enter') { event.preventDefault(); submit(); } });
    frame(action.title, stepLabel(), [el('label', step.label, 'wizard-label'), field, error], [link('رجوع', back), nextButton]);
    field.focus();
  };

  const drawReview = () => {
    const error = el('p', '', 'text-danger');
    const list = el('div', undefined, 'wizard-review');
    action.summary(values).forEach(([label, value]) => {
      const line = el('div', undefined, 'wizard-review-line');
      line.append(el('span', label), el('strong', value));
      list.append(line);
    });
    const runButton = link('تنفيذ', () => execute(error, runButton), action.danger ? 'btn-danger' : 'btn-primary');
    frame('مراجعة: ' + action.title, stepLabel(), [el('p', action.description, 'muted'), list, error], [link('رجوع', back), runButton]);
  };

  const draw = () => {
    if (!action) { drawPicker(); return; }
    const steps = stepsNow();
    if (index < steps.length) drawStep(steps[index]);
    else drawReview();
  };
  draw();
}

function actionButton(actions) {
  return link('اتخاذ إجراء', () => openActionWindow(actions), 'btn-primary', 'check');
}

/// Sends a form with files, which needs the sign-in header without a JSON body
async function sendForm(path, form, isRetry) {
  const res = await safeFetch(API + path, { method: 'POST', headers: { Authorization: 'Bearer ' + session?.accessToken }, body: form });
  if (res.status === 401 && !isRetry && await refreshSession()) return sendForm(path, form, true);
  const json = await readJson(res);
  if (!res.ok) throw new Error(friendlyError(res.status, json.error));
  return json;
}

function messageCard(message, owner) {
  const kind = message.author === 'ADMIN' ? 'admin' : message.author === 'NOTE' ? 'note' : 'user';
  const card = el('div', undefined, 'ticket-message ticket-' + kind);
  const head = el('div', undefined, 'ticket-message-head');
  const who = el('span', undefined, 'message-author');
  who.append(
    icon(kind === 'admin' ? 'apply' : kind === 'note' ? 'note' : owner.user_role === 'lawyer' ? 'lawyer' : 'client'),
    el('strong', kind === 'admin' ? 'رد الإدارة' : kind === 'note' ? 'ملاحظة داخلية (لا يراها ' + owner.user_name + ')' : owner.user_name));
  head.append(who, el('span', date(message.createdAt), 'muted'));
  card.append(head);
  if (message.body) card.append(el('p', message.body));
  if (message.images.length) {
    const images = el('div', undefined, 'ticket-images');
    message.images.forEach((path) => images.append(privateImage(path)));
    card.append(images);
  }
  return card;
}

/// The ticket conversation in a window: Enter sends, Shift+Enter starts a new line
function openChat(ticket) {
  const MAX_IMAGES = 5;
  let files = [];
  let sending = false;
  const close = () => { $('dialog').hidden = true; $('dialog').replaceChildren(); render(); };

  const backdrop = el('div', undefined, 'modal-backdrop');
  const card = el('div', undefined, 'modal-card chat-card');
  const head = el('div', undefined, 'modal-header');
  const titleBox = el('div', undefined, 'modal-title-box');
  titleBox.append(el('h3', 'الشات: ' + ticket.reference), el('span', ticket.user_name, 'wizard-step'));
  head.append(titleBox, closeIcon(close));
  const thread = el('div', undefined, 'chat-thread');
  const previews = el('div', undefined, 'chat-previews');
  const error = el('p', '', 'text-danger chat-error');

  const picker = el('input');
  picker.type = 'file';
  picker.accept = 'image/*';
  picker.multiple = true;
  picker.hidden = true;
  const showPreviews = () => {
    previews.replaceChildren(...files.map((file, index) => {
      const item = el('button', undefined, 'chat-preview');
      item.type = 'button';
      item.title = 'إزالة الصورة';
      const image = el('img');
      image.src = URL.createObjectURL(file);
      image.alt = '';
      item.append(image, icon('close', 'ui-icon'));
      item.addEventListener('click', () => { files.splice(index, 1); showPreviews(); });
      return item;
    }));
  };
  picker.addEventListener('change', () => {
    files = [...files, ...picker.files].slice(0, MAX_IMAGES);
    if (picker.files.length + files.length > MAX_IMAGES) error.textContent = 'الحد الأقصى ' + MAX_IMAGES + ' صور';
    picker.value = '';
    showPreviews();
  });

  const attach = el('button', undefined, 'chat-attach');
  attach.type = 'button';
  attach.title = 'إرفاق صور';
  attach.setAttribute('aria-label', 'إرفاق صور');
  attach.append(icon('image'));
  attach.addEventListener('click', () => picker.click());

  const field = el('textarea', undefined, 'field-input chat-input');
  field.rows = 1;
  field.placeholder = 'اكتب رسالتك، واضغط Enter للإرسال';

  const load = async () => {
    const { data } = await api('GET', '/admin/support/' + ticket.id);
    thread.replaceChildren(...data.messages.map((message) => messageCard(message, data)));
    thread.scrollTop = thread.scrollHeight;
  };
  const send = async () => {
    if (sending) return;
    const text = field.value.trim();
    if (!text && !files.length) return;
    sending = true;
    sendButton.classList.add('is-loading');
    error.textContent = '';
    const form = new FormData();
    form.append('body', text);
    files.forEach((file) => form.append('images', file));
    try {
      await sendForm('/admin/support/' + ticket.id + '/reply', form);
      field.value = '';
      files = [];
      showPreviews();
      await load();
    } catch (err) {
      error.textContent = err.message;
    } finally {
      sending = false;
      sendButton.classList.remove('is-loading');
      field.focus();
    }
  };
  field.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && !event.shiftKey && !event.isComposing) {
      event.preventDefault();
      send();
    }
  });
  const sendButton = link('إرسال', send, 'btn-primary', 'check');

  const composer = el('div', undefined, 'chat-composer');
  composer.append(attach, field, sendButton, picker);
  card.append(head, thread, previews, error, composer);
  backdrop.append(card);
  $('dialog').replaceChildren(backdrop);
  $('dialog').hidden = false;
  load().catch((err) => { error.textContent = err.message; });
  field.focus();
}
