import * as activity from './activity/activity.service.js';
import * as fasting from './fasting/fasting.service.js';
import * as hydration from './hydration/hydration.service.js';
import * as mealplans from './mealplans/mealplan.service.js';
import * as foods from './foods/food.service.js';

export async function snapshot(req, res, next) {
  try {
    const user_id = req.user?.id || req.query.user_id;

    if (!user_id) {
      return res.status(400).json({ ok: false, error: 'Missing user_id' });
    }

    // -------------------------
    // ACTIVITY
    // -------------------------
    const actToday = await activity.getTodayGlance(user_id);
    const actRollup7 = await activity.getRollup7(user_id);   // <-- ADD HERE

    // -------------------------
    // HYDRATION
    // -------------------------
    const hydToday = await hydration.todayGlance(user_id);

    // -------------------------
    // FASTING
    // -------------------------
    const fastSummary = await fasting.getSummary(user_id);

    // -------------------------
    // MEAL PLANS
    // -------------------------
    const userPlans = await mealplans.getUserPlans(user_id);

    let activePlan = null;
    if (userPlans?.length) {
      activePlan = await mealplans.getPlan(userPlans[0].meal_plan_id);
    }

    // -------------------------
    // RESPONSE
    // -------------------------
    res.json({
      ok: true,
      user_id,
      activity: {
        today: actToday || {},
        weekly: actRollup7 || {}
      },
      hydration: hydToday || {},
      fasting: fastSummary || {},
      mealplan: activePlan || null
    });

  } catch (e) {
    next(e);
  }
}