// Los 14 alérgenos del Anexo II del Reglamento UE 1169/2011 son un
// catálogo fijo por ley, igual para todos los restaurantes — se
// traducen como texto estático, sin pasar por la IA (a diferencia de
// la carta, que es contenido libre de cada restaurante).
export const ALERGENO_LABEL_IDIOMA = {
  en: {
    gluten: 'Gluten', crustaceos: 'Crustaceans', huevos: 'Eggs', pescado: 'Fish',
    cacahuetes: 'Peanuts', soja: 'Soybeans', lacteos: 'Milk', frutos_cascara: 'Tree nuts',
    apio: 'Celery', mostaza: 'Mustard', sesamo: 'Sesame', sulfitos: 'Sulphites',
    altramuces: 'Lupin', moluscos: 'Molluscs',
  },
  fr: {
    gluten: 'Gluten', crustaceos: 'Crustacés', huevos: 'Œufs', pescado: 'Poisson',
    cacahuetes: 'Arachides', soja: 'Soja', lacteos: 'Lait', frutos_cascara: 'Fruits à coque',
    apio: 'Céleri', mostaza: 'Moutarde', sesamo: 'Sésame', sulfitos: 'Sulfites',
    altramuces: 'Lupin', moluscos: 'Mollusques',
  },
  de: {
    gluten: 'Gluten', crustaceos: 'Krebstiere', huevos: 'Eier', pescado: 'Fisch',
    cacahuetes: 'Erdnüsse', soja: 'Soja', lacteos: 'Milch', frutos_cascara: 'Schalenfrüchte',
    apio: 'Sellerie', mostaza: 'Senf', sesamo: 'Sesam', sulfitos: 'Sulfite',
    altramuces: 'Lupinen', moluscos: 'Weichtiere',
  },
  it: {
    gluten: 'Glutine', crustaceos: 'Crostacei', huevos: 'Uova', pescado: 'Pesce',
    cacahuetes: 'Arachidi', soja: 'Soia', lacteos: 'Latte', frutos_cascara: 'Frutta a guscio',
    apio: 'Sedano', mostaza: 'Senape', sesamo: 'Sesamo', sulfitos: 'Solfiti',
    altramuces: 'Lupini', moluscos: 'Molluschi',
  },
  pt: {
    gluten: 'Glúten', crustaceos: 'Crustáceos', huevos: 'Ovos', pescado: 'Peixe',
    cacahuetes: 'Amendoins', soja: 'Soja', lacteos: 'Leite', frutos_cascara: 'Frutos de casca rija',
    apio: 'Aipo', mostaza: 'Mostarda', sesamo: 'Sésamo', sulfitos: 'Sulfitos',
    altramuces: 'Tremoço', moluscos: 'Moluscos',
  },
  ar: {
    gluten: 'الغلوتين', crustaceos: 'القشريات', huevos: 'البيض', pescado: 'السمك',
    cacahuetes: 'الفول السوداني', soja: 'الصويا', lacteos: 'الحليب', frutos_cascara: 'المكسرات',
    apio: 'الكرفس', mostaza: 'الخردل', sesamo: 'السمسم', sulfitos: 'الكبريتيت',
    altramuces: 'الترمس', moluscos: 'الرخويات',
  },
}

// alergenos: catálogo ALERGENOS de la pantalla (con key/label/emoji en
// español). Devuelve el mismo catálogo con "label" sustituido si hay
// traducción para el idioma pedido.
export function traducirAlergenos(alergenos, idioma) {
  const dic = ALERGENO_LABEL_IDIOMA[idioma]
  if (!dic) return alergenos
  return alergenos.map(a => ({ ...a, label: dic[a.key] || a.label }))
}
