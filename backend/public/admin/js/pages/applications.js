const SERVICE_FILTERS = [['PENDING', 'طلبات التقديم'], ['APPROVED', 'الخدمة مفعلة'], ['REJECTED', 'طلبات مرفوضة']];
const SERVICE_STATUS = { PENDING: ['بانتظار المراجعة', 'amber'], APPROVED: ['مفعلة', 'green'], REJECTED: ['مرفوض', 'red'] };

/// Everyone who applied for the service: decide on new applications and follow the rest
async function applicationsPage(box) {
  const q = current.search || '';
  const filter = current.filter || 'PENDING';
  const [{ data: pending }, { data: lawyers }] = await Promise.all([
    api('GET', '/admin/urgent-applications'),
    api('GET', '/admin/users?role=lawyer&q=' + encodeURIComponent(q)),
  ]);
  const applications = new Map(pending.map((item) => [item.user_id, item]));
  const count = (status) => lawyers.filter((item) => item.urgent_status === status).length;
  const applied = (item) => applications.get(item.id)?.urgent_terms_accepted_at || item.created_at;
  const shown = applyFilters(lawyers.filter((item) => item.urgent_status === filter), applied);

  box.append(summaryBar([
    ['طلبات التقديم', count('PENDING'), 'lawyer', 'amber'],
    ['الخدمة مفعلة', count('APPROVED'), 'check', 'green'],
    ['طلبات مرفوضة', count('REJECTED'), 'reject', 'red'],
  ]));
  box.append(guide('راجع الصورة الشخصية وصورة الكارنيه وبيانات المحامي قبل الموافقة.',
    'بعد الموافقة يتمكن المحامي من استقبال طلبات «محاميك حالاً»، ويظهر للموكلين على الخريطة عند إتاحته.'));
  box.append(controlsBar([
    searchBox(q, 'ابحث بالاسم أو الهاتف أو البريد', (value) => { current.search = value; render(); }),
    filterButtons(SERVICE_FILTERS, filter, (key) => { current.filter = key; render(); }, 'حالة الخدمة', 'apply'),
    ...dateFilters(),
  ]));

  const openLawyer = (item) => (applications.has(item.id) ? open('application', applications.get(item.id)) : open('user', item.id));
  box.append(table(['الاسم', 'الهاتف', 'رقم القيد', 'سنوات الخبرة', 'تاريخ التسجيل', 'الحالة', 'الإجراءات'], shown.map((item) => ({
    item,
    cells: [
      el('strong', item.full_name || 'دون اسم', 'prod-name-ar'), item.phone, item.syndicate_number || 'غير مسجل', item.experience_years ?? 0,
      date(item.created_at), badge(...SERVICE_STATUS[item.urgent_status]), link('فتح', () => openLawyer(item), 'btn-outline btn-xs', 'open'),
    ],
  })), openLawyer));
}

/// The card is private, so it is fetched with the admin sign-in and shown from memory
async function privateDocument(id) {
  const load = () => fetch(API + '/lawyers/documents/' + id, { headers: { Authorization: 'Bearer ' + session?.accessToken } });
  let res = await load();
  if (res.status === 401 && await refreshSession()) res = await load();
  if (!res.ok) throw new Error('تعذر تحميل صورة الكارنيه');
  return URL.createObjectURL(await res.blob());
}

function documentBox(title, content) {
  const box = el('figure', undefined, 'doc-box');
  box.append(content, el('figcaption', title));
  return box;
}

function missingDocument(text) {
  const node = el('div', undefined, 'doc-missing');
  node.append(icon('complaint'), el('span', text));
  return node;
}

async function documentsGrid(item) {
  const grid = el('div', undefined, 'doc-grid');

  if (item.photo) {
    grid.append(documentBox('الصورة الشخصية', imageThumb(item.photo, 'الصورة الشخصية')));
  } else {
    grid.append(documentBox('الصورة الشخصية', missingDocument('لم يرفع المحامي صورته بعد')));
  }

  if (!item.card_id) {
    grid.append(documentBox('كارنيه النقابة', missingDocument('لم يرفع المحامي صورة الكارنيه بعد')));
  } else {
    try {
      const url = await privateDocument(item.card_id);
      if (item.card_mime === 'application/pdf') {
        const view = el('a');
        view.href = url;
        view.target = '_blank';
        view.rel = 'noopener';
        view.className = 'btn btn-outline';
        view.append(icon('open'), el('span', 'فتح ملف الكارنيه'));
        grid.append(documentBox('كارنيه النقابة', view));
      } else {
        grid.append(documentBox('كارنيه النقابة', imageThumb(url, 'كارنيه النقابة')));
      }
    } catch (err) {
      grid.append(documentBox('كارنيه النقابة', missingDocument(err.message)));
    }
  }
  return grid;
}

/// An application opens as the lawyer's profile, with the decision as its action
function applicationPage(box) {
  return userPage(box, current.param);
}

function applicationActions(item) {
  const decide = (approve, reason) => decideAndReturn(() =>
    api('POST', '/admin/urgent-applications/' + item.user_id + '/decision', { approve, reason }));
  return [
    {
      title: 'الموافقة على الطلب', description: 'يتيح للمحامي استقبال طلبات «محاميك حالاً».', steps: [], success: 'تمت الموافقة',
      summary: () => [['المحامي', item.full_name]], run: () => decide(true),
    },
    {
      title: 'رفض الطلب', description: 'يرفض الطلب، ويصل إلى المحامي إشعار بالسبب.', success: 'تم الرفض', danger: true,
      steps: [{ key: 'reason', type: 'text', label: 'ما سبب الرفض؟', min: 3 }],
      summary: (values) => [['المحامي', item.full_name], ['السبب', values.reason]], run: (values) => decide(false, values.reason),
    },
  ];
}
