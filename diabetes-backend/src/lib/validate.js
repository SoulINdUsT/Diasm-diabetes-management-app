// src/lib/validate.js
export function validate(schema) {
  return (req, res, next) => {
    try {
      req.validated = schema.parse(req.body ?? {});
      next();
    } catch (e) {
      return res.status(400).json({
        error: 'Validation error',
        details: e.errors?.map(x => ({ path: x.path, message: x.message })) ?? [],
      });
    }
  };
}
