namespace JC.LocationIngest.Models
{
    public class JCLoginResponse
    {
        public string AccessToken { get; set; } = default!;
        public DateTime ExpiresAtUtc { get; set; }
    }
}
