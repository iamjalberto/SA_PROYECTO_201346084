# Contratos de API – Delivereats Fase 3
## Servicios gRPC (Protocol Buffers)

**Protocolo**: gRPC / Protocol Buffers 3  
**Definiciones**: `/proto/*.proto`  
**Fase**: 3 – Sin cambios en contratos de negocio existentes.  
La Fase 3 agrega el método `SendOrderRejected` al `NotificationService`, invocado por el CronJob de rechazo automático de órdenes.

---

## 1. AuthService (`proto/auth.proto`)

| Método | Request | Response | Descripción |
|--------|---------|----------|-------------|
| `Register` | `RegisterRequest` | `RegisterResponse` | Registro de nuevo usuario |
| `Login` | `LoginRequest` | `LoginResponse` | Autenticación, retorna JWT |
| `ValidateToken` | `ValidateTokenRequest` | `ValidateTokenResponse` | Validación de token JWT |
| `ListUsers` | `ListUsersRequest` | `ListUsersResponse` | Lista todos los usuarios (admin) |

**Campos clave**:
```protobuf
message RegisterRequest  { string name = 1; string email = 2; string password = 3; string role = 4; }
message LoginResponse    { string token = 1; string role = 2; int32 user_id = 3; }
message ValidateTokenResponse { bool valid = 1; int32 user_id = 2; string role = 3; }
```

---

## 2. OrderService (`proto/order.proto`)

| Método | Request | Response | Descripción |
|--------|---------|----------|-------------|
| `CreateOrder` | `CreateOrderRequest` | `OrderResponse` | Crea una nueva orden |
| `GetOrder` | `GetOrderRequest` | `OrderResponse` | Consulta orden por ID |
| `ListOrdersByClient` | `ListOrdersByClientRequest` | `ListOrdersResponse` | Órdenes de un cliente |
| `ListOrdersByRestaurant` | `ListOrdersByRestaurantRequest` | `ListOrdersResponse` | Órdenes de un restaurante |
| `ListReadyOrders` | `ListReadyOrdersRequest` | `ListOrdersResponse` | Órdenes listas para delivery |
| `UpdateOrderStatus` | `UpdateOrderStatusRequest` | `OrderResponse` | Actualiza estado de la orden |
| `CancelOrder` | `CancelOrderRequest` | `OrderResponse` | Cancela una orden |
| `ListAllOrders` | `ListAllOrdersRequest` | `ListOrdersResponse` | Lista todas las órdenes (admin) |

**Estados de orden**: `CREADA` → `ACEPTADA` → `EN_CAMINO` → `ENTREGADA` / `RECHAZADA` / `CANCELADA`

```protobuf
message UpdateOrderStatusRequest { int32 order_id = 1; string status = 2; }
// status válidos: ACEPTADA, RECHAZADA, EN_CAMINO, ENTREGADA, CANCELADA
```

> **Fase 3**: El CronJob `order-auto-reject` llama directamente a la DB (no via gRPC) para mayor atomicidad, pero usa `NotificationService.SendOrderRejected` para notificar al cliente.

---

## 3. NotificationService (`proto/notification.proto`)

| Método | Request | Response | Fase | Descripción |
|--------|---------|----------|------|-------------|
| `SendOrderCreated` | `OrderCreatedNotification` | `NotificationResponse` | F1 | Email al cliente al crear orden |
| `SendOrderCancelledByClient` | `OrderCancelledNotification` | `NotificationResponse` | F1 | Email al cancelar |
| `SendOrderInRoute` | `OrderInRouteNotification` | `NotificationResponse` | F2 | Email cuando sale a entrega |
| `SendOrderCancelledByRestaurant` | `OrderCancelledByThirdNotification` | `NotificationResponse` | F2 | Cancelación por restaurante |
| `SendOrderCancelledByDelivery` | `OrderCancelledByThirdNotification` | `NotificationResponse` | F2 | Cancelación por delivery |
| `SendOrderRejected` | `OrderRejectedNotification` | `NotificationResponse` | **F3 NEW** | Email por rechazo automático del CronJob |

**Nuevo en Fase 3**:
```protobuf
message OrderRejectedNotification {
  int32  order_id       = 1;
  string customer_email = 2;
  string customer_name  = 3;
  string reason         = 4;  // "No fue aceptada en 60 minutos"
  string rejected_at    = 5;  // ISO 8601 timestamp
}
```

---

## 4. PaymentService (`proto/payment.proto`)

| Método | Request | Response | Descripción |
|--------|---------|----------|-------------|
| `ProcessPayment` | `ProcessPaymentRequest` | `ProcessPaymentResponse` | Procesa pago de una orden |
| `GetPaymentStatus` | `GetPaymentStatusRequest` | `GetPaymentStatusResponse` | Consulta estado del pago |
| `ApproveRefund` | `ApproveRefundRequest` | `ApproveRefundResponse` | Aprueba reembolso |
| `ListPayments` | `ListPaymentsRequest` | `ListPaymentsResponse` | Lista pagos (admin) |
| `CreateCoupon` | `CreateCouponRequest` | `CouponResponse` | Crea cupón de descuento |
| `ValidateCoupon` | `ValidateCouponRequest` | `ValidateCouponResponse` | Valida y aplica cupón |
| `ListCoupons` | `ListCouponsRequest` | `ListCouponsResponse` | Lista cupones |
| `DeleteCoupon` | `DeleteCouponRequest` | `CouponResponse` | Elimina cupón |
| `GetWalletBalance` | `GetWalletBalanceRequest` | `WalletResponse` | Consulta saldo de wallet |
| `RechargeWallet` | `RechargeWalletRequest` | `WalletResponse` | Recarga wallet |
| `GetWalletTransactions` | `GetWalletTransactionsRequest` | `WalletTransactionsResponse` | Historial de wallet |

---

## 5. RestaurantCatalogService (`proto/restaurant.proto`)

| Método | Request | Response | Descripción |
|--------|---------|----------|-------------|
| `CreateRestaurant` | `CreateRestaurantRequest` | `RestaurantResponse` | Crea restaurante |
| `GetRestaurant` | `GetRestaurantRequest` | `RestaurantResponse` | Consulta restaurante por ID |
| `UpdateRestaurant` | `UpdateRestaurantRequest` | `RestaurantResponse` | Actualiza restaurante |
| `DeleteRestaurant` | `DeleteRestaurantRequest` | `GenericResponse` | Elimina restaurante |
| `ListRestaurants` | `ListRestaurantsRequest` | `ListRestaurantsResponse` | Lista restaurantes |
| `SearchRestaurants` | `SearchRestaurantsRequest` | `ListRestaurantsResponse` | Búsqueda por nombre/categoría |
| `CreateMenuItem` | `CreateMenuItemRequest` | `MenuItemResponse` | Agrega ítem al menú |
| `GetMenuItem` | `GetMenuItemRequest` | `MenuItemResponse` | Consulta ítem de menú |
| `UpdateMenuItem` | `UpdateMenuItemRequest` | `MenuItemResponse` | Actualiza ítem |
| `DeleteMenuItem` | `DeleteMenuItemRequest` | `GenericResponse` | Elimina ítem del menú |
| `ListMenuItems` | `ListMenuItemsRequest` | `ListMenuItemsResponse` | Lista menú de un restaurante |
| `CreatePromotion` | `CreatePromotionRequest` | `PromotionResponse` | Crea promoción |
| `ListPromotions` | `ListPromotionsRequest` | `ListPromotionsResponse` | Lista promociones |
| `DeletePromotion` | `DeletePromotionRequest` | `GenericResponse` | Elimina promoción |

---

## 6. DeliveryService (`proto/delivery.proto`)

| Método | Request | Response | Descripción |
|--------|---------|----------|-------------|
| `AcceptOrder` | `AcceptOrderRequest` | `DeliveryResponse` | Repartidor acepta una orden lista |
| `UpdateDeliveryStatus` | `UpdateDeliveryStatusRequest` | `DeliveryResponse` | Actualiza estado del delivery |
| `GetDeliveryByOrder` | `GetDeliveryByOrderRequest` | `DeliveryResponse` | Consulta delivery por orden |
| `ListAvailableOrders` | `ListAvailableOrdersRequest` | `ListDeliveriesResponse` | Órdenes disponibles para tomar |
| `ListMyDeliveries` | `ListMyDeliveriesRequest` | `ListDeliveriesResponse` | Entregas del repartidor |
| `UploadEvidence` | `UploadEvidenceRequest` | `EvidenceResponse` | Sube foto de evidencia de entrega |
| `GetEvidence` | `GetEvidenceRequest` | `EvidenceResponse` | Obtiene evidencia de entrega |
| `ListDeliveredOrders` | `ListDeliveredOrdersRequest` | `ListDeliveriesResponse` | Lista de entregas completadas |

---

## 7. FXService (`proto/fx_service.proto`)

| Método | Request | Response | Descripción |
|--------|---------|----------|-------------|
| `GetExchangeRate` | `ExchangeRateRequest` | `ExchangeRateResponse` | Tasa de conversión entre dos monedas |
| `GetMultipleRates` | `MultipleRatesRequest` | `MultipleRatesResponse` | Tasas para múltiples pares de moneda |

```protobuf
message ExchangeRateRequest  { string from_currency = 1; string to_currency = 2; }
message ExchangeRateResponse { double rate = 1; string timestamp = 2; bool cached = 3; }
```

---

## 8. RatingService (`proto/rating.proto`)

| Método | Request | Response | Descripción |
|--------|---------|----------|-------------|
| `CreateRating` | `CreateRatingRequest` | `RatingResponse` | Crea calificación |
| `GetRatingsByRestaurant` | `GetRatingsByEntityRequest` | `ListRatingsResponse` | Calificaciones de un restaurante |
| `GetRatingsByDelivery` | `GetRatingsByEntityRequest` | `ListRatingsResponse` | Calificaciones de un repartidor |
| `GetRatingsByProduct` | `GetRatingsByEntityRequest` | `ListRatingsResponse` | Calificaciones de un producto |
| `GetAverageRating` | `GetRatingsByEntityRequest` | `AverageRatingResponse` | Promedio de calificaciones |

---

## 9. REST Endpoints (API Gateway – `api-gateway/src/`)

El API Gateway expone los servicios gRPC como REST/JSON:

| Método HTTP | Ruta | Servicio gRPC | Descripción |
|-------------|------|---------------|-------------|
| `POST` | `/api/auth/register` | AuthService.Register | Registro |
| `POST` | `/api/auth/login` | AuthService.Login | Login |
| `GET` | `/api/restaurants` | RestaurantCatalogService.ListRestaurants | Listar restaurantes |
| `GET` | `/api/restaurants/search` | RestaurantCatalogService.SearchRestaurants | Buscar restaurantes |
| `GET` | `/api/restaurants/:id/menu` | RestaurantCatalogService.ListMenuItems | Ver menú |
| `POST` | `/api/orders` | OrderService.CreateOrder | Crear orden |
| `GET` | `/api/orders/:id` | OrderService.GetOrder | Ver orden |
| `PATCH` | `/api/orders/:id/status` | OrderService.UpdateOrderStatus | Cambiar estado |
| `POST` | `/api/payments` | PaymentService.ProcessPayment | Pagar |
| `GET` | `/api/payments/status` | PaymentService.GetPaymentStatus | Estado pago |
| `GET` | `/api/fx/rates` | FXService.GetExchangeRate | Tasa de cambio |
| `GET` | `/health` | — | Health check del gateway |

---

## Cambios Fase 3 (resumen)

| Contrato | Cambio | Detalle |
|----------|--------|---------|
| `notification.proto` | **ADICIÓN** | Nuevo mensaje `OrderRejectedNotification` y método `SendOrderRejected` para soporte del CronJob de auto-rechazo |
| Todos los demás | Sin cambios | Los contratos de negocio de Fases 1/2 no se modificaron en Fase 3 |
