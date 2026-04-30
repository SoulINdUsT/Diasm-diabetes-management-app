import pool from '../../../config/db.js';

// --- column map ---
const COL = {
  id: 'id',
  code: 'code',
  name_en: 'name_en',
  name_bn: 'name_bn',
  name_bn_translated: 'name_bn_translated',
  category: 'category',
  kcal: 'kcal_per_100g',
  carb_g: 'carb_g',
  protein_g: 'protein_g',
  fat_g: 'fat_g',
  fiber_g: 'fiber_g',
  sodium_mg: 'sodium_mg',
};

// ---------------- foods ----------------
export async function createFood(d) {
  const [res] = await pool.query(
    `INSERT INTO foods
      (code,name_en,name_bn,category,kcal_per_100g,carb_g,protein_g,fat_g,fiber_g,sodium_mg,source_ref)
     VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
    [
      d.code ?? null, d.name_en ?? null, d.name_bn ?? null, d.category ?? null,
      d.kcal_per_100g ?? null, d.carb_g ?? null, d.protein_g ?? null,
      d.fat_g ?? null, d.fiber_g ?? null, d.sodium_mg ?? null, d.source_ref ?? null
    ]
  );
  return res.insertId;
}

export async function getFoodById(id) {
  const [r] = await pool.query(
    `SELECT * FROM foods WHERE id=?`,
    [id]
  );
  return r[0] || null;
}

export async function listFoods({ q, limit=20, offset=0, kcal_min, kcal_max, order='name_en' }) {
  const w=[], p=[];
  if (q) { const like=`%${q}%`; w.push('(name_en LIKE ? OR name_bn LIKE ? OR code LIKE ?)'); p.push(like,like,like); }
  if (kcal_min!=null){ w.push('kcal_per_100g>=?'); p.push(kcal_min); }
  if (kcal_max!=null){ w.push('kcal_per_100g<=?'); p.push(kcal_max); }
  const where=w.length?`WHERE ${w.join(' AND ')}`:'';
  const orderSql=['name_en','kcal_per_100g','id'].includes(order)?order:'name_en';
  const [rows]=await pool.query(`SELECT * FROM foods ${where} ORDER BY ${orderSql} LIMIT ? OFFSET ?`,[...p,limit,offset]);
  const [[{total}={total:0}]]=await pool.query(`SELECT COUNT(*) AS total FROM foods ${where}`,p);
  return {rows,total};
}

export async function updateFood(id,d){
  const f=[],p=[];
  for(const[k,v]of Object.entries(d)){ if(v!==undefined){ f.push(`${k}=?`); p.push(v);} }
  if(!f.length)return 0;
  const [r]=await pool.query(`UPDATE foods SET ${f.join(',')},updated_at=NOW() WHERE id=?`,[...p,id]);
  return r.affectedRows;
}
export async function deleteFood(id){
  const [r]=await pool.query(`DELETE FROM foods WHERE id=?`,[id]);
  return r.affectedRows;
}

// ---------------- portions ----------------
// LIST portions
export async function listPortions(food_id) {
  const [rows] = await pool.query(
    `
    SELECT
      id,
      food_id,
      label_en,
      label_bn,
      grams
    FROM food_portions
    WHERE food_id = ?
    ORDER BY grams ASC
    `,
    [food_id]
  );
  return rows;
}

// CREATE portion
export async function createPortion(food_id, body) {
  // Accept legacy {label} and the new {label_en,label_bn}
  const label_en = body.label_en ?? body.label ?? '';
  const label_bn = body.label_bn ?? null;
  const grams = body.grams;

  const [res] = await pool.query(
    `INSERT INTO food_portions (food_id, label_en, label_bn, grams) VALUES (?, ?, ?, ?)`,
    [food_id, label_en, label_bn, grams]
  );
  return res.insertId;
}

// UPDATE portion
export async function updatePortion(id, body) {
  const sets = [];
  const params = [];

  if (body.label_en !== undefined || body.label !== undefined) {
    sets.push('label_en = ?');
    params.push(body.label_en ?? body.label ?? '');
  }
  if (body.label_bn !== undefined) {
    sets.push('label_bn = ?');
    params.push(body.label_bn);
  }
  if (body.grams !== undefined) {
    sets.push('grams = ?');
    params.push(body.grams);
  }
  if (!sets.length) return 0;

  const [res] = await pool.query(
    `UPDATE food_portions SET ${sets.join(', ')} WHERE id = ?`,
    [...params, id]
  );
  return res.affectedRows;
}

export async function deletePortion(id){
  const [r]=await pool.query(`DELETE FROM food_portions WHERE id=?`,[id]);
  return r.affectedRows;
}

