const ACCOUNT_FILTERS = [['', 'كل الحالات'], ['active', 'نشط'], ['suspended', 'موقوف']];
const SERVICE_NAME = 'محاميك حالاً';
const LAWYER_FILTERS = [...ACCOUNT_FILTERS, ['service-on', 'الخدمة مفعلة'], ['service-off', 'الخدمة غير مفعلة']];
const OFF_REASONS = { MANUAL: 'أوقفها المحامي', MISSED: 'لم يرد على طلب', NO_LOCATION: 'الموقع غير محدث', SUSPENDED: 'الحساب موقوف' };
const hasService = (item) => item.urgent_status === 'APPROVED';
const matchesAccountFilter = (item, filter) => {
  if (filter === 'service-on') return hasService(item);
  if (filter === 'service-off') return !hasService(item);
  return !filter || item.status === filter;
};

function usersPage(role) {
  return async (box) => {
    const isLawyer = role === 'lawyer';
    const q = current.search || '';
    const filter = current.filter || '';
    const { data } = await api('GET', '/admin/users?role=' + role + '&q=' + encodeURIComponent(q));
    const shown = applyFilters(data.filter((item) => matchesAccountFilter(item, filter)), (item) => item.created_at);

    box.append(summaryBar([
      [isLawyer ? 'إجمالي المحامين' : 'إجمالي الموكلين', data.length, isLawyer ? 'lawyer' : 'client', 'brand'],
      ['حسابات نشطة', data.filter((item) => item.status === 'active').length, 'check', 'green'],
      ['حسابات موقوفة', data.filter((item) => item.status === 'suspended').length, 'power', 'red'],
      ...(isLawyer ? [['الخدمة مفعلة', data.filter(hasService).length, 'apply', 'green']] : []),
      ['إجمالي الطلبات', sumOf(data, 'orders_count'), 'orders', 'blue'],
      ['حسابات عليها شكاوى', data.filter((item) => item.user_against > 0).length, 'complaint', 'amber'],
    ]));
    box.append(guide('افتح الملف الشخصي لمراجعة الطلبات والشكاوى، ولتنفيذ الإجراءات على الحساب.',
      isLawyer ? 'تظهر هنا كل حسابات المحامين، سواء كانت خدمة «محاميك حالاً» مفعلة لهم أو لا.' : 'إيقاف الحساب يمنع صاحبه من استخدام التطبيق كليًا حتى تفعيله مرة أخرى.'));
    box.append(controlsBar([
      searchBox(q, 'ابحث بالاسم أو الهاتف أو البريد', (value) => { current.search = value; render(); }),
      filterButtons(isLawyer ? LAWYER_FILTERS : ACCOUNT_FILTERS, filter, (key) => { current.filter = key; render(); }),
      ...dateFilters(),
    ]));

    const headers = isLawyer
      ? ['الاسم', 'الهاتف', 'سنوات الخبرة', 'التقييم', SERVICE_NAME, 'الحالة', 'الإجراءات']
      : ['الاسم', 'الهاتف', 'تاريخ التسجيل', 'الحالة', 'الإجراءات'];
    const rows = shown.map((item) => {
      const tools = link('الملف', () => open('user', item.id), 'btn-outline btn-xs', 'open');

      const name = el('strong', item.full_name || 'دون اسم', 'prod-name-ar');
      const cells = isLawyer
        ? [name, item.phone, item.experience_years ?? 0, Number(item.rating ?? 0).toFixed(1) + ' / 5', hasService(item) ? badge('مفعلة', 'green') : badge('غير مفعلة', 'gray'), accountState(item), tools]
        : [name, item.phone, date(item.created_at), accountState(item), tools];
      return { item, cells };
    });
    box.append(table(headers, rows, (item) => open('user', item.id)));
  };
}

/// The profile page. For an application it offers the decision only, and its tables wait for the approval
async function userPage(box, isApplication = false) {
  const { data } = await api('GET', '/admin/users/' + current.param);
  const { user } = data;
  const isLawyer = user.role === 'lawyer';

  const badges = [statusRow(isLawyer ? 'lawyer' : 'client', 'نوع الحساب', badge(isLawyer ? 'محامٍ' : 'موكل', 'blue')), statusRow('power', 'حالة الحساب', accountState(user))];
  const activeStrikes = (data.strikes || []).filter((item) => !item.revoked_at).length;
  const activeWarningsCount = data.warnings.filter((item) => !item.revoked_at).length;
  badges.push(statusRow('complaint', 'الإنذارات السارية', badge(activeWarningsCount + ' من 3', activeWarningsCount ? 'amber' : 'gray')));
  if (isLawyer) badges.push(statusRow('complaint', 'المخالفات السارية', badge(activeStrikes + ' من 3', activeStrikes ? 'amber' : 'gray')));
  if (isLawyer) {
    const [serviceText, serviceColor] = { APPROVED: ['مفعلة', 'green'], PENDING: ['قيد المراجعة', 'amber'], REJECTED: ['مرفوضة', 'red'] }[user.urgent_status] || ['غير مفعلة', 'gray'];
    badges.push(statusRow('apply', SERVICE_NAME, badge(serviceText, serviceColor)));
    badges.push(statusRow('check', 'متاح الآن', user.is_available ? badge('نعم', 'green') : badge('لا', 'gray')));
    if (!user.is_available && user.availability_off_reason) {
      badges.push(statusRow('complaint', 'سبب عدم الإتاحة', badge(OFF_REASONS[user.availability_off_reason] || user.availability_off_reason, 'amber')));
    }
    badges.push(statusRow('calendar', 'آخر تحديث للموقع', el('span', date(user.last_location_updated_at), 'hero-status-text')));
  }
  box.append(hero(avatarBox(user.photo, isLawyer ? 'lawyer' : 'client'), user.full_name || 'حساب', badges,
    [['phone', user.phone], ['mail', user.email], ['calendar', 'تاريخ التسجيل: ' + date(user.created_at)]], [actionButton(isApplication ? applicationActions(user) : userActions(user, data))]));

  const stats = [['الطلبات', user.user_orders, 'orders', 'blue'], ['شكاوى ضده', user.user_against, 'complaint', 'red'],
    ['شكاوى قدمها', user.user_filed, 'appeal', 'amber'], ['الإنذارات', user.warnings_count, 'power', 'gray']];
  if (isLawyer) stats.unshift(['التقييم', Number(user.rating ?? 0).toFixed(1) + ' / 5', 'review', 'green']);
  const balance = Number((isLawyer ? data.wallet?.available : data.wallet?.client_balance) || 0);
  stats.unshift(['الرصيد الحالي', balance + ' ج.م', 'money', balance < 0 ? 'red' : 'green']);
  box.append(summaryBar(stats));

  const list = [
    ['data', 'البيانات'],
    ['activity', 'النشاط', data.orders.length + data.tickets.length + data.reviews.length],
    ['wallet', 'الرصيد والإنذارات', data.warnings.filter((item) => !item.revoked_at).length],
  ];
  const active = list.some(([key]) => key === current.tab) ? current.tab : 'data';
  box.append(tabs(list, active, (key) => { current.tab = key; render(); }));

  const pane = el('div', undefined, 'tab-content-pane' + (isApplication && active !== 'data' ? ' locked-tables' : ''));
  if (active === 'data') {
    pane.append(section('بيانات الحساب', details([
      ['الاسم', user.full_name], ['الهاتف', user.phone], ['البريد', user.email], ['تاريخ التسجيل', date(user.created_at)],
    ])));
    if (isLawyer) {
      pane.append(section('الصورة وكارنيه النقابة', await documentsGrid(user)));
      pane.append(section('البيانات المهنية', details([
        ['رقم القيد', user.syndicate_number], ['سنوات الخبرة', user.experience_years ?? 0], ['عدد التقييمات', user.reviews_count],
      ])));
    }
  } else if (active === 'activity') {
    pane.append(section('الطلبات', table(['رقم الطلب', 'المشكلة', 'المبلغ', 'الحالة', 'التاريخ'], data.orders.map((item) => ({
      item, cells: [copyable(item.order_number), item.problem_type, item.price + ' ج.م', tag(item.status), date(item.created_at)],
    })), (item) => open('order', item.id))));
    pane.append(section('التذاكر', table(['رقم التذكرة', 'العنوان', 'النوع', 'الطلب', 'الحالة', 'التاريخ'], data.tickets.map((item) => ({
      item, cells: [copyable(item.reference), item.title, TICKET_CATEGORY[item.category] || item.category, orderLink(item.order_number), ticketStatus(item.status), date(item.created_at)],
    })), (item) => open('ticket', item.id))));
    pane.append(section('التقييمات', table(['رقم الطلب', 'التقييم', 'التعليق', 'التاريخ'], data.reviews.map((item) => ({
      item, cells: [copyable(item.order_number), item.rating + ' / 5', item.comment, date(item.created_at)],
    })), (item) => open('order', item.order_id))));
    if (isLawyer) {
      pane.append(section('المخالفات', table(['النوع', 'رقم الطلب', 'التاريخ', 'الحالة'], data.strikes.map((item) => ({
        item, cells: [STRIKE_KINDS[item.kind] || item.kind, copyOr(item.order_number), date(item.created_at), item.revoked_at ? badge('ملغاة', 'gray') : badge('سارية', 'red')],
      })))));
    }
  } else {
    walletPane(pane, data, user, isLawyer);
  }
  box.append(pane);
}

function money(value) {
  const amount = Number(value || 0);
  return el('strong', (amount > 0 ? '+' : '') + amount + ' ج.م', amount < 0 ? 'text-danger' : 'text-success');
}

/// Manual balance changes and warnings, each one with its reason
function walletPane(pane, data, user, isLawyer) {
  const wallet = data.wallet || {};
  pane.append(summaryBar(isLawyer
    ? [['الرصيد المتاح', Number(wallet.available) + ' ج.م', 'money', Number(wallet.available) < 0 ? 'red' : 'green'],
      ['أتعاب محجوزة', Number(wallet.held) + ' ج.م', 'calendar', 'amber'], ['أتعاب مجمدة', Number(wallet.frozen) + ' ج.م', 'power', 'blue']]
    : [['رصيد الموكل', Number(wallet.client_balance) + ' ج.م', 'money', Number(wallet.client_balance) < 0 ? 'red' : 'green']]));

  if (!isLawyer) pane.append(section('مدفوعات الموكل', paymentsTable(data.payments, false)));

  const ledger = isLawyer ? data.adjustments : data.credits;
  pane.append(section(isLawyer ? 'إضافات وخصومات الرصيد' : 'كل حركات الرصيد', table(['المبلغ', 'السبب', 'رقم الطلب', 'بواسطة', 'التاريخ'], ledger.map((item) => ({
    item, cells: [money(item.amount), item.reason, copyOr(item.order_number), item.created_by || 'تلقائي', date(item.created_at)],
  })))));

  const rows = data.warnings.map((item) => ({
    item,
    cells: [
      item.reason, copyOr(item.order_number), item.created_by || 'تلقائي', date(item.created_at),
      item.revoked_at ? badge('ملغى', 'gray') : badge('سارٍ', 'red'),
    ],
  }));
  pane.append(section('الإنذارات',
    table(['السبب', 'رقم الطلب', 'بواسطة', 'التاريخ', 'الحالة'], rows)));
}

// First match wins, so the specific names come before the general ones
const ACTION_ICONS = [
  [/^فك تجميد/, 'unlock', 'tone-green'], [/^تجميد/, 'freeze', 'tone-blue'],
  [/^تحويل/, 'transfer', 'tone-blue'], [/^خصم/, 'minus', 'tone-red'], [/^إضافة/, 'plus', 'tone-green'],
  [/^إلغاء إنذار/, 'close', 'tone-blue'], [/إنذار/, 'complaint', 'tone-amber'],
  [/^الرد/, 'appeal', 'tone-blue'], [/ملاحظة/, 'note', 'tone-blue'], [/^إغلاق/, 'lock', 'tone-red'],
  [/^رد المبلغ/, 'money', 'tone-red'], [/^صرف/, 'money', 'tone-green'],
  [/^إيقاف/, 'power', 'tone-red'], [/^تفعيل/, 'power', 'tone-green'],
  [/^الموافقة/, 'check', 'tone-green'], [/^رفض/, 'reject', 'tone-red'],
  [/^إبقاء/, 'show', 'tone-green'], [/^إخفاء/, 'hide', 'tone-red'],
  [/^تعديل سعر/, 'price', 'tone-blue'], [/نسبة/, 'percent', 'tone-blue'],
  [/^بدء التواصل/, 'phone', 'tone-blue'], [/^لم نتمكن/, 'phone', 'tone-amber'], [/^تمت/, 'check', 'tone-green'], [/استشارة/, 'phone', 'tone-blue'],
];

// Icons that share a row because their actions are close to each other
const ACTION_ROWS = { appeal: 'write', note: 'write', complaint: 'warnings', close: 'warnings', check: 'decision', reject: 'decision', show: 'decision', hide: 'decision', freeze: 'freezing', unlock: 'freezing' };

/// One action in its own box: what it is, what it does, and its controls
function actionTile(title, description, ...controls) {
  const box = el('div', undefined, 'action-tile');
  const text = el('div', undefined, 'action-text');
  const match = ACTION_ICONS.find(([pattern]) => pattern.test(title));
  box.dataset.row = (match && ACTION_ROWS[match[1]]) || (match ? match[1] : 'other');
  const glyph = el('span', undefined, 'action-icon ' + (match ? match[2] : 'tone-blue'));
  glyph.append(icon(match ? match[1] : 'ticket'));
  const head = el('div', undefined, 'action-head');
  head.append(glyph, el('h4', title));
  text.append(head, el('p', description));
  const tools = el('div', undefined, 'action-controls');
  tools.append(...controls);
  box.append(text, tools);
  return box;
}

/// The actions come last: a title, then separate boxes with no box around them
function actionsSection(tiles) {
  const wrap = el('div', undefined, 'actions-area');
  const rows = new Map();
  tiles.forEach((tile) => {
    if (!rows.has(tile.dataset.row)) {
      const row = el('div', undefined, 'action-row');
      rows.set(tile.dataset.row, row);
    }
    rows.get(tile.dataset.row).append(tile);
  });
  wrap.append(el('h3', 'الإجراءات', 'actions-title'), ...rows.values());
  return wrap;
}

/// Everything the admin can do to an account, each with its steps
const STRIKE_KINDS = { WITHDRAWAL: 'اعتذار بعد الدفع', COMPLAINT: 'شكوى' };

function isSuspendedByStrikes(user) {
  return Boolean(user.suspended_until) && new Date(user.suspended_until) > new Date();
}

/// The account's real state: suspended by the admin, by warnings until a date, or by strikes until a date
function accountState(user) {
  // Google's reviewers sign in with it: never suspended or deleted
  if (user.is_review_account) return badge('حساب مراجعة جوجل', 'blue');
  if (user.status === 'suspended') {
    return badge(user.account_suspended_until ? 'موقوف بسبب الإنذارات حتى ' + date(user.account_suspended_until) : 'موقوف بقرار الإدارة', 'red');
  }
  if (isSuspendedByStrikes(user)) return badge('موقوف بسبب المخالفات حتى ' + date(user.suspended_until), 'red');
  return accountTag(user.status);
}

function userActions(user, data) {
  const moneyAction = (title, description, sign, success) => ({
    title, description, success, danger: sign < 0,
    steps: [AMOUNT_STEP, REASON_STEP, { key: 'orderNumber', type: 'text', label: 'رقم الطلب (اختياري)', optional: true }],
    summary: (values) => [['المبلغ', values.amount + ' ج.م'], ['السبب', values.reason], ...(values.orderNumber ? [['رقم الطلب', values.orderNumber]] : [])],
    run: (values) => api('POST', '/admin/users/' + user.id + '/balance', { amount: sign * Number(values.amount), reason: values.reason, orderNumber: values.orderNumber || undefined }),
  });
  const suspended = user.status === 'suspended' || isSuspendedByStrikes(user);
  const activeWarnings = data.warnings.filter((item) => !item.revoked_at);
  const activeStrikes = (data.strikes || []).filter((item) => !item.revoked_at);
  return [
    {
      title: suspended ? 'تفعيل الحساب' : 'إيقاف الحساب', description: suspended ? 'يرفع أي إيقاف، سواء من الإدارة أو بسبب الإنذارات أو المخالفات، ويعيد لصاحب الحساب استخدام التطبيق.' : 'يمنع صاحب الحساب من استخدام التطبيق حتى تفعّله مرة أخرى.',
      steps: [], danger: !suspended, success: suspended ? 'تم تفعيل الحساب' : 'تم إيقاف الحساب',
      summary: () => [['الحساب', user.full_name || user.phone]],
      run: () => api('POST', '/admin/users/' + user.id + '/status', { suspend: !suspended }),
    },
    moneyAction('إضافة', 'يزيد رصيد الحساب، وتتحمل المنصة المبلغ.', 1, 'تمت الإضافة'),
    moneyAction('خصم', 'ينقص رصيد الحساب، وإذا زاد الخصم على الرصيد أصبح سالبًا ويُسدَّد مما يدخل لاحقًا.', -1, 'تم تنفيذ الخصم'),
    {
      title: 'إنذار', description: 'يسجل إنذارًا، وثلاثة إنذارات خلال 30 يومًا توقف الحساب أسبوعًا تلقائيًا.', steps: [REASON_STEP, { key: 'orderNumber', type: 'text', label: 'رقم الطلب (اختياري)', optional: true }], success: 'تم توجيه الإنذار', danger: true,
      summary: (values) => [['السبب', values.reason], ...(values.orderNumber ? [['رقم الطلب', values.orderNumber]] : [])],
      run: (values) => api('POST', '/admin/users/' + user.id + '/warnings', { reason: values.reason, orderNumber: values.orderNumber || undefined }),
    },
    ...(activeWarnings.length ? [{
      title: 'إلغاء إنذار', description: 'يلغي الإنذار الذي تختاره، ولا يرفع إيقافًا قائمًا.', success: 'تم إلغاء الإنذار',
      steps: [{ key: 'warning', type: 'choice', label: 'أي إنذار تريد إلغاءه؟', options: activeWarnings.map((item) => [item.id, item.reason]) }],
      summary: (values) => [['الإنذار', activeWarnings.find((item) => item.id === values.warning).reason]],
      run: (values) => api('POST', '/admin/warnings/' + values.warning + '/revoke', {}),
    }] : []),
    ...(activeStrikes.length ? [{
      title: 'إلغاء مخالفة', description: 'يلغي المخالفة التي تختارها. وإذا قلت المخالفات السارية عن ثلاث، يُرفع إيقاف المخالفات تلقائيًا.', success: 'تم إلغاء المخالفة',
      steps: [{ key: 'strike', type: 'choice', label: 'أي مخالفة تريد إلغاءها؟', options: activeStrikes.map((item) => [item.id, (STRIKE_KINDS[item.kind] || item.kind) + ' • ' + date(item.created_at)]) }],
      summary: (values) => [['المخالفة', STRIKE_KINDS[activeStrikes.find((item) => item.id === values.strike).kind] || '']],
      run: (values) => api('POST', '/admin/strikes/' + values.strike + '/revoke', {}),
    }] : []),
  ];
}
