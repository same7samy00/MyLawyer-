// Account deletion from the website: the person signs in with the same details as the app, then asks for the
// deletion. The server checks everything (open orders, balance...) and says why when it refuses.
(function () {
  var form = document.getElementById('delete-form');
  var result = document.getElementById('result');
  var button = form.querySelector('button');

  function show(text, ok) {
    result.textContent = text;
    result.className = 'result ' + (ok ? 'ok' : 'bad');
    result.hidden = false;
  }

  function post(path, body, token) {
    var headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = 'Bearer ' + token;
    return fetch('/api/v1' + path, { method: 'POST', headers: headers, body: JSON.stringify(body) })
      .then(function (res) { return res.json().catch(function () { return {}; }).then(function (json) { return { status: res.status, json: json }; }); });
  }

  form.addEventListener('submit', function (event) {
    event.preventDefault();
    var identifier = form.identifier.value.trim();
    var password = form.password.value;
    if (!identifier || !password) return show('اكتب رقم الموبايل أو الإيميل وكلمة السر', false);

    if (!window.confirm('متأكد إنك عايز تحذف حسابك؟ بياناتك هتتمسح بعد 30 يوم')) return;
    button.disabled = true;
    result.hidden = true;

    post('/auth/login', { identifier: identifier, password: password })
      .then(function (login) {
        var token = login.json && login.json.data && login.json.data.accessToken;
        if (login.status !== 200 || !token) throw new Error((login.json && login.json.error) || 'بيانات الدخول غلط');
        return post('/users/me/delete', { password: password }, token);
      })
      .then(function (deletion) {
        if (deletion.status !== 200) throw new Error((deletion.json && deletion.json.error) || 'تعذر حذف الحساب دلوقتي');
        var at = new Date(deletion.json.data.deleteAt).toLocaleDateString('ar-EG', { day: 'numeric', month: 'long', year: 'numeric' });
        form.reset();
        show('اتسجل طلبك. حسابك خرج من كل الأجهزة، وبياناتك هتتمسح يوم ' + at + '. لو دخلت تاني قبلها، الحذف بيتلغي.', true);
      })
      .catch(function (err) { show(err.message, false); })
      .then(function () { button.disabled = false; });
  });
})();
