namespace JC.LocationIngest.Models
{
    public class JCInventLocationUpdateLocationRequest
    {
        public decimal? Latitude { get; init; }
        public decimal? Longitude { get; init; }
        public decimal? AccuracyM { get; init; }
    }
}
