-- Precio mensual de cada plan (definido tras la investigación de
-- mercado: carta QR simple 15-30€/mes, GoTab Pro 99$, CoverManager
-- desde 99€/mes+comisión por reserva, TPV completo 200-500€/mes).
-- Nosotros sin comisión por uso, cuota fija.
alter table planes add column if not exists precio numeric(10,2);

update planes set precio = 35 where key = 'basico';
update planes set precio = 89 where key = 'profesional';
update planes set precio = 169 where key = 'premium';

notify pgrst, 'reload schema';
