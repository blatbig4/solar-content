/* SOLAR CLOUD · hướng dẫn — signature interaction: rail đo sáng theo bước đang xem */
(function () {
  var secs = document.querySelectorAll('.sec');
  if (!secs.length) return;
  if (!('IntersectionObserver' in window)) {
    secs.forEach(function (s) { s.classList.add('active'); });
    return;
  }
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (e.isIntersecting) e.target.classList.add('active');
    });
  }, { rootMargin: '0px 0px -55% 0px', threshold: 0.01 });
  secs.forEach(function (s) { io.observe(s); });
})();
