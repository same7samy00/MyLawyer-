const ACCOUNT_FILTERS = [['', 'كل الحالات'], ['active', 'نشط'], ['suspended', 'موقوف']];

function usersPage(role) {
  return async (box) => {
    const isLawyer = role === 'lawyer';
    const q = current.search || '';
    const filter = current.filter || '';
    const res = await api('GET', '/admin/users?role=' + role + '&q=' + encodeURIComponent(q));
    // A lawyer joins the list only after the admin approves the application
    const data = isLawyer ? res.data.filter((item) => item.urgent_status === 'APPROVED') : res.data;
    const shown = applyFilters(filter ? data.filter((item) => item.status === filter) : data, (item) => item.created_at);

    box.append(summaryBar([
      [isLawyer ? 'إجمالي المحامين' : 'إجمالي الموكلين', data.length, isLawyer ? 'lawyer' : 'client', 'brand'],
      ['حسابات نشطة', data.filter((item) => item.status === 'active').length, 'check', 'green'],
      ['حسابات موقوفة', data.filter((item) => item.status === 'suspended').length, 'power', 'red'],
      ['إجمالي الطلبات', sumOf(data, 'orders_count'), 'orders', 'blue'],
      ['حسابات عليها شكاوى', data.filter((item) => item.user_against > 0).length, 'complaint', 'amber'],
    ]));
    box.append(guide('افتح الملف الشخصي لمراجعة الطلبات والشكاوى، ولتنفيذ الإجراءات على الحساب.',
      isLawyer ? 'لا يظهر المحامي في هذه القائمة إلا بعد الموافقة على طلب انضمامه.' : 'إيقاف الحساب يمنع صاحبه من استخدام التطبيق كليًا حتى تفعيله مرة أخرى.'));
    box.append(controlsBar([
      searchBox(q, 'ابحث بالاسم أو الهاتف أو البريد', (value) => { current.search = value; render(); }),
      filterButtons(ACCOUNT_FILTERS, filter, (key) => { current.filter = key; render(); }),
      ...dateFilters(),
    ]));

    const headers = isLawyer
      ? ['الاسم', 'الهاتف', 'سنوات الخبرة', 'التقييم', 'الحالة', 'الإجراءات']
      : ['الاسم', 'الهاتف', 'تاريخ التسجيل', 'الحالة', 'الإجراءات'];
    const rows = shown.map((item) => {
      const tools = link('الملف', () => open('user', item.id), 'btn-outline btn-xs', 'open');

      const name = el('div', undefined, 'person-inline');
      name.append(personAvatar(item.full_name, item.photo), el('strong', item.full_name || 'دون اسم', 'prod-name-ar'));
      const cells = isLawyer
        ? [name, item.phone, item.experience_years ?? 0, Number(item.rating ?? 0).toFixed(1) + ' / 5', accountTag(item.status), tools]
        : [name, item.phone, date(item.created_at), accountTag(item.status), tools];
      return { item, cells };
    });
    box.append(table(headers, rows, (item) => open('user', item.id)));
  };
}

async function userPage(box) {
  const { data } = await api('GET', '/admin/users/' + current.param);
  const { user } = data;
  const isLawyer = user.role === 'lawyer';

  const badges = [badge(isLawyer ? 'محامٍ' : 'موكل', 'blue'), accountTag(user.status)];
  if (isLawyer) badges.push(badge(user.urgent_status === 'APPROVED' ? 'معتمد للخدمة' : 'غير معتمد', user.urgent_status === 'APPROVED' ? 'green' : 'gray'));
  box.append(hero(avatarBox(user.photo, isLawyer ? 'lawyer' : 'client'), user.full_name || 'حساب', badges,
    [['phone', user.phone], ['mail', user.email], ['calendar', 'تاريخ التسجيل: ' + date(user.created_at)]], [actionButton(userActions(user, data))]));

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

  const pane = el('div', undefined, 'tab-content-pane');
  if (active === 'data') {
    pane.append(section('بيانات الحساب', details([
      ['الاسم', user.full_name], ['الهاتف', user.phone], ['البريد', user.email], ['تاريخ التسجيل', date(user.created_at)],
    ])));
    if (isLawyer) {
      pane.append(section('الصورة وبطاقة النقابة', await documentsGrid(user)));
      pane.append(section('البيانات المهنية', details([
        ['رقم القيد', user.syndicate_number], ['سنوات الخبرة', user.experience_years ?? 0], ['عدد التقييمات', user.reviews_count],
      ])));
      pane.append(section('الإتاحة والموقع', details([
        ['متاح الآن', user.is_available ? 'نعم' : 'لا'], ['سبب عدم الإتاحة', user.availability_off_reason],
        ['آخر تحديث للموقع', date(user.last_location_updated_at)],
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
      pane.append(section('المخالفات', table(['النوع', 'التاريخ'], data.strikes.map((item) => ({ item, cells: [{ WITHDRAWAL: 'اعتذار بعد الدفع', COMPLAINT: 'شكوى' }[item.kind] || item.kind, date(item.created_at)] })))));
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
function userActions(user, data) {
  const moneyAction = (title, description, sign, success) => ({
    title, description, success, danger: sign < 0,
    steps: [AMOUNT_STEP, REASON_STEP, { key: 'orderNumber', type: 'text', label: 'رقم الطلب (اختياري)', optional: true }],
    summary: (values) => [['المبلغ', values.amount + ' ج.م'], ['السبب', values.reason], ...(values.orderNumber ? [['رقم الطلب', values.orderNumber]] : [])],
    run: (values) => api('POST', '/admin/users/' + user.id + '/balance', { amount: sign * Number(values.amount), reason: values.reason, orderNumber: values.orderNumber || undefined }),
  });
  const suspended = user.status === 'suspended';
  const activeWarnings = data.warnings.filter((item) => !item.revoked_at);
  return [
    {
      title: suspended ? 'تفعيل الحساب' : 'إيقاف الحساب', description: suspended ? 'يعيد لصاحب الحساب استخدام التطبيق.' : 'يمنع صاحب الحساب من استخدام التطبيق حتى تفعّله مرة أخرى.',
      steps: [], danger: !suspended, success: suspended ? 'تم تفعيل الحساب' : 'تم إيقاف الحساب',
      summary: () => [['الحساب', user.full_name || user.phone]],
      run: () => api('POST', '/admin/users/' + user.id + '/status', { suspend: !suspended }),
    },
    moneyAction('إضافة', 'يزيد رصيد الحساب، وتتحمل المنصة المبلغ.', 1, 'تمت الإضافة'),
    moneyAction('خصم', 'ينقص رصيد الحساب، وإذا زاد الخصم على الرصيد أصبح سالبًا ويُسدَّد مما يدخل لاحقًا.', -1, 'تم تنفيذ الخصم'),
    {
      title: 'إنذار', description: 'يسجل إنذارًا، وثلاثة إنذارات خلال 30 يومًا توقف الحساب أسبوعًا تلقائيًا.', steps: [REASON_STEP], success: 'تم توجيه الإنذار', danger: true,
      summary: (values) => [['السبب', values.reason]],
      run: (values) => api('POST', '/admin/users/' + user.id + '/warnings', { reason: values.reason }),
    },
    ...(activeWarnings.length ? [{
      title: 'إلغاء إنذار', description: 'يلغي الإنذار الذي تختاره، ولا يرفع إيقافًا قائمًا.', success: 'تم إلغاء الإنذار',
      steps: [{ key: 'warning', type: 'choice', label: 'أي إنذار تريد إلغاءه؟', options: activeWarnings.map((item) => [item.id, item.reason]) }],
      summary: (values) => [['الإنذار', activeWarnings.find((item) => item.id === values.warning).reason]],
      run: (values) => api('POST', '/admin/warnings/' + values.warning + '/revoke', {}),
    }] : []),
  ];
}
