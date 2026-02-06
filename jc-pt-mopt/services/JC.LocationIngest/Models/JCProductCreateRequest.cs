namespace JC.LocationIngest.Models
{
    public class JCProductCreateRequest
    {
        public required string ItemId { get; init; }
        public required string NameAlias { get; init; }
        public string? Barcode { get; init; }
        public bool? Active { get; init; }
    }
}
