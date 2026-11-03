const FREEZE_TEXT = {
  freeze: ['تجميد الأتعاب', 'يمنع المحامي من سحب أتعاب هذا الطلب حتى يُفك التجميد.'],
  unfreeze: ['فك تجميد الأتعاب', 'يسمح للمحامي بسحب أتعاب هذا الطلب بعد مرور 24 ساعة من إنهاء المهمة، أو فورًا إذا كانت قد مرت.'],
};

function freezeAction(orderId, frozen) {
  const [title, description] = FREEZE_TEXT[frozen ? 'unfreeze' : 'freeze'];
  return {
    title, description, steps: [], danger: !frozen, success: frozen ? 'تم فك التجميد' : 'تم تجميد الأتعاب',
    summary: () => [['الإجراء', title]],
    run: () => api('POST', '/admin/orders/' + orderId + '/freeze', { freeze: !frozen }),
  };
}

/// The actions of one ticket, each with its steps
function ticketActions(data) {
  const people = data.order
    ? [[data.order.lawyer_id, 'المحامي'], [data.order.client_id, 'الموكل']]
    : [[data.user_id, data.user_role === 'lawyer' ? 'المحامي' : 'الموكل']];
  const nameOf = (id) => people.find(([value]) => value === id)[1];
  const personOf = (values) => values.person || people[0][0];
  const personSteps = (label) => (people.length > 1 ? [{ key: 'person', type: 'choice', label, options: people }] : []);

  const moneyAction = (title, description, sign, success, question) => ({
    title, description, success, danger: sign < 0,
    steps: [...personSteps(question), AMOUNT_STEP, REASON_STEP],
    summary: (values) => [['الحساب', nameOf(personOf(values))], ['المبلغ', values.amount + ' ج.م'], ['السبب', values.reason]],
    run: (values) => api('POST', '/admin/users/' + personOf(values) + '/balance', { amount: sign * Number(values.amount), reason: values.reason, orderNumber: data.order?.order_number }),
  });

  const list = [{
    title: 'ملاحظة داخلية', description: 'تُحفظ للفريق فقط، ولا يراها صاحب التذكرة.', success: 'تم حفظ الملاحظة', noReview: true,
    steps: [{ key: 'body', type: 'long', label: 'اكتب الملاحظة' }],
    run: (values) => api('POST', '/admin/support/' + data.id + '/note', { body: values.body }),
  }];
  if (data.order) {
    list.push({
      title: 'تحويل', description: 'يخصم المبلغ من طرف ويضيفه إلى الطرف الآخر في خطوة واحدة.', success: 'تم تنفيذ التحويل',
      steps: [{ key: 'from', type: 'choice', label: 'من أين إلى أين؟', options: [['lawyer', 'من المحامي إلى الموكل'], ['client', 'من الموكل إلى المحامي']] }, AMOUNT_STEP, REASON_STEP],
      summary: (values) => [['الاتجاه', values.from === 'lawyer' ? 'من المحامي إلى الموكل' : 'من الموكل إلى المحامي'], ['المبلغ', values.amount + ' ج.م'], ['السبب', values.reason]],
      run: (values) => api('POST', '/admin/support/' + data.id + '/transfer', { from: values.from, amount: Number(values.amount), reason: values.reason }),
    });
  }
  list.push(
    moneyAction('خصم', 'ينقص رصيد الطرف الذي تختاره، دون إضافة المبلغ إلى أحد.', -1, 'تم تنفيذ الخصم', 'من تريد الخصم منه؟'),
    moneyAction('إضافة', 'يزيد رصيد الطرف الذي تختاره، وتتحمل المنصة المبلغ.', 1, 'تمت الإضافة', 'لمن تريد الإضافة؟'),
    {
      title: 'إنذار', description: 'يسجل إنذارًا، وثلاثة إنذارات خلال 30 يومًا توقف الحساب أسبوعًا تلقائيًا.', success: 'تم توجيه الإنذار', danger: true,
      steps: [...personSteps('من تريد إنذاره؟'), REASON_STEP],
      summary: (values) => [['الحساب', nameOf(personOf(values))], ['السبب', values.reason]],
      run: (values) => api('POST', '/admin/users/' + personOf(values) + '/warnings', { reason: values.reason, orderNumber: data.order?.order_number }),
    });
  if (data.order && ['HELD', 'AVAILABLE', 'FROZEN'].includes(data.order.payout_status)) {
    list.push(freezeAction(data.order.id, data.order.payout_status === 'FROZEN'));
  }
  list.push({
    title: 'إغلاق التذكرة', description: 'يغلق التذكرة فلا يمكن الرد عليها، ولا يغير الأموال.', success: 'تم إغلاق التذكرة', danger: true,
    steps: [
      { key: 'mode', type: 'choice', label: 'كيف تريد الإغلاق؟', options: [['message', 'برسالة أخيرة'], ['silent', 'دون رسالة']] },
      { key: 'body', type: 'long', label: 'اكتب الرسالة الأخيرة', when: (values) => values.mode === 'message' },
    ],
    summary: (values) => [['الإغلاق', values.mode === 'message' ? 'برسالة أخيرة' : 'دون رسالة'], ...(values.mode === 'message' ? [['الرسالة', values.body]] : [])],
    run: (values) => decideAndReturn(() => api('POST', '/admin/support/' + data.id + '/close', { body: values.mode === 'message' ? values.body : undefined })),
  });
  return list;
}
