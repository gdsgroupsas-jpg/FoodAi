/**
 * Tipo standard per le risposte delle Server Actions.
 * Tutte le azioni restituiscono questo formato.
 */
export type ActionResult<T = void> = { success: true; data: T } | { success: false; error: string };
