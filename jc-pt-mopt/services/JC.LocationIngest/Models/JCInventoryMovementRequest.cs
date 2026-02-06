namespace JC.LocationIngest.Models;

public sealed class JCInventoryMovementRequest
{
    public required string ItemId { get; init; }              // GR300002
    public required string InventLocationId { get; init; }    // BOD-01

    public required string MovementType { get; init; }        // IN | OUT | ADJUST | TRANSFER
    public required decimal Qty { get; init; }                // > 0

    public string? Reason { get; init; }
    public string? Voucher { get; init; }

    // Geolocalización (móvil)
    public decimal? Latitude { get; init; }
    public decimal? Longitude { get; init; }
    public decimal? AccuracyM { get; init; }
    public DateTimeOffset? DeviceTime { get; init; }
}
