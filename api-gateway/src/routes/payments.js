const express = require("express");
const {
  paymentClient,
  fxClient,
  orderClient,
  grpcCall,
} = require("../grpcClients");
const { authenticateToken, authorizeRoles } = require("../middleware");

const router = express.Router();

// POST /api/payments - Procesar pago (CLIENTE)
router.post(
  "/",
  authenticateToken,
  authorizeRoles("CLIENTE"),
  async (req, res) => {
    try {
      const {
        order_id,
        payment_type,
        card_number,
        card_holder,
        card_expiry,
        card_cvv,
        amount,
        currency,
      } = req.body;

      if (!order_id || !payment_type || !amount) {
        return res.status(400).json({
          success: false,
          message: "order_id, payment_type y amount son requeridos",
        });
      }

      // Si la moneda no es GTQ, consultar tipo de cambio
      let converted_amount = amount;
      let converted_currency = "GTQ";
      let exchange_rate = 1.0;

      if (currency && currency !== "GTQ") {
        try {
          const fxResponse = await grpcCall(fxClient, "GetExchangeRate", {
            from_currency: currency,
            to_currency: "GTQ",
            amount: amount,
          });
          if (fxResponse.rate) {
            converted_amount = amount * fxResponse.rate;
            converted_currency = "GTQ";
            exchange_rate = fxResponse.rate;
          }
        } catch (fxError) {
          console.error("[API-Gateway] FX conversion error:", fxError);
          return res.status(500).json({
            success: false,
            message: "Error al convertir moneda. Intente con GTQ.",
          });
        }
      }

      // Mapear tipo de pago al enum del proto
      let paymentTypeEnum;
      switch (payment_type) {
        case "TARJETA_CREDITO":
          paymentTypeEnum = 0;
          break;
        case "TARJETA_DEBITO":
          paymentTypeEnum = 1;
          break;
        case "CARTERA_DIGITAL":
          paymentTypeEnum = 2;
          break;
        default:
          return res.status(400).json({
            success: false,
            message: "Tipo de pago inválido",
          });
      }

      const response = await grpcCall(paymentClient, "ProcessPayment", {
        order_id: parseInt(order_id),
        customer_id: req.user.id,
        amount: parseFloat(amount),
        currency: currency || "GTQ",
        payment_type: paymentTypeEnum,
        card_number: card_number || "",
        card_holder_name: card_holder || "",
        card_expiry: card_expiry || "",
        card_cvv: card_cvv || "",
        converted_amount: parseFloat(converted_amount),
        converted_currency,
        exchange_rate: parseFloat(exchange_rate),
      });

      // Si el pago fue exitoso, actualizar estado de la orden
      if (response.success) {
        grpcCall(orderClient, "UpdateOrderStatus", {
          id: parseInt(order_id),
          status: "PAGADA",
          updated_by: req.user.id,
          updated_by_role: "CLIENTE",
          updated_by_name: req.user.name,
        }).catch((err) =>
          console.error("[API-Gateway] Order update after payment error:", err),
        );
      }

      res.json(response);
    } catch (error) {
      console.error("[API-Gateway] Process payment error:", error);
      res
        .status(500)
        .json({ success: false, message: "Error al procesar pago" });
    }
  },
);

// GET /api/payments/all - Listar todos los pagos (ADMINISTRADOR)
router.get(
  "/all",
  authenticateToken,
  authorizeRoles("ADMINISTRADOR"),
  async (req, res) => {
    try {
      const response = await grpcCall(paymentClient, "ListPayments", {});
      res.json(response);
    } catch (error) {
      res
        .status(500)
        .json({ success: false, message: "Error al listar pagos" });
    }
  },
);

// POST /api/payments/refund - Aprobar devolución (ADMINISTRADOR)
router.post(
  "/refund",
  authenticateToken,
  authorizeRoles("ADMINISTRADOR"),
  async (req, res) => {
    try {
      const { payment_id, reason } = req.body;
      if (!payment_id) {
        return res
          .status(400)
          .json({ success: false, message: "payment_id es requerido" });
      }

      const response = await grpcCall(paymentClient, "ApproveRefund", {
        order_id: parseInt(payment_id),
        admin_id: req.user.id,
        reason: reason || "Devolución aprobada por administrador",
      });
      res.json(response);
    } catch (error) {
      console.error("[API-Gateway] Refund error:", error);
      res
        .status(500)
        .json({ success: false, message: "Error al procesar devolución" });
    }
  },
);

// GET /api/payments/wallet - Obtener saldo de cartera (CLIENTE)
router.get(
  "/wallet",
  authenticateToken,
  authorizeRoles("CLIENTE"),
  async (req, res) => {
    try {
      const response = await grpcCall(paymentClient, "GetWalletBalance", {
        customer_id: req.user.id,
      });
      res.json(response);
    } catch (error) {
      res
        .status(500)
        .json({ success: false, message: "Error al consultar cartera" });
    }
  },
);

// POST /api/payments/wallet/recharge - Recargar cartera (CLIENTE)
router.post(
  "/wallet/recharge",
  authenticateToken,
  authorizeRoles("CLIENTE"),
  async (req, res) => {
    try {
      const { amount, description } = req.body;
      if (!amount || amount <= 0) {
        return res
          .status(400)
          .json({ success: false, message: "Monto debe ser mayor a 0" });
      }
      const response = await grpcCall(paymentClient, "RechargeWallet", {
        customer_id: req.user.id,
        amount: parseFloat(amount),
        description: description || "Recarga de cartera",
      });
      res.json(response);
    } catch (error) {
      res
        .status(500)
        .json({ success: false, message: "Error al recargar cartera" });
    }
  },
);

// GET /api/payments/wallet/transactions - Historial de cartera (CLIENTE)
router.get(
  "/wallet/transactions",
  authenticateToken,
  authorizeRoles("CLIENTE"),
  async (req, res) => {
    try {
      const response = await grpcCall(paymentClient, "GetWalletTransactions", {
        customer_id: req.user.id,
      });
      res.json(response);
    } catch (error) {
      res
        .status(500)
        .json({ success: false, message: "Error al consultar transacciones" });
    }
  },
);

// ===================== CUPONES =====================

// GET /api/payments/:orderId - Obtener estado del pago (CLIENTE, ADMINISTRADOR)
// NOTA: debe ir DESPUÉS de rutas estáticas (/wallet, /all, /refund, /coupons/*)
router.get("/:orderId", authenticateToken, async (req, res) => {
  try {
    const response = await grpcCall(paymentClient, "GetPaymentStatus", {
      order_id: parseInt(req.params.orderId),
    });
    res.json(response);
  } catch (error) {
    res
      .status(500)
      .json({ success: false, message: "Error al consultar pago" });
  }
});

// POST /api/payments/coupons - Crear cupón (ADMINISTRADOR)
router.post(
  "/coupons",
  authenticateToken,
  authorizeRoles("ADMINISTRADOR"),
  async (req, res) => {
    try {
      const response = await grpcCall(paymentClient, "CreateCoupon", req.body);
      res.status(201).json(response);
    } catch (error) {
      console.error("[API-Gateway] Create coupon error:", error);
      res.status(500).json({ success: false, message: "Error al crear cupón" });
    }
  },
);

// POST /api/payments/coupons/validate - Validar cupón (CLIENTE)
router.post(
  "/coupons/validate",
  authenticateToken,
  authorizeRoles("CLIENTE"),
  async (req, res) => {
    try {
      const { code, order_amount } = req.body;
      const response = await grpcCall(paymentClient, "ValidateCoupon", {
        code,
        order_amount: parseFloat(order_amount),
      });
      res.json(response);
    } catch (error) {
      console.error("[API-Gateway] Validate coupon error:", error);
      res.status(500).json({ valid: false, message: "Error al validar cupón" });
    }
  },
);

// GET /api/payments/coupons/list - Listar cupones (ADMINISTRADOR)
router.get(
  "/coupons/list",
  authenticateToken,
  authorizeRoles("ADMINISTRADOR"),
  async (req, res) => {
    try {
      const response = await grpcCall(paymentClient, "ListCoupons", {});
      res.json(response);
    } catch (error) {
      res
        .status(500)
        .json({ success: false, message: "Error al listar cupones" });
    }
  },
);

// DELETE /api/payments/coupons/:id - Eliminar cupón (ADMINISTRADOR)
router.delete(
  "/coupons/:id",
  authenticateToken,
  authorizeRoles("ADMINISTRADOR"),
  async (req, res) => {
    try {
      const response = await grpcCall(paymentClient, "DeleteCoupon", {
        id: parseInt(req.params.id),
      });
      res.json(response);
    } catch (error) {
      res
        .status(500)
        .json({ success: false, message: "Error al eliminar cupón" });
    }
  },
);

module.exports = router;
