namespace JC.LocationIngest.Models
{
    public class JCInventLocationCreateRequest
    {
        public required string InventLocationId { get; init; }
        public required string Name { get; init; }

        public bool? Active { get; init; }
        public bool? IsMobile { get; init; }

        public string? DeviceId { get; init; }
        public string? Plate { get; init; }
        public string? DriverName { get; init; }

        // Ubicación inicial 
        public decimal? Latitude { get; init; }
        public decimal? Longitude { get; init; }
        public decimal? AccuracyM { get; init; }
    }
}
