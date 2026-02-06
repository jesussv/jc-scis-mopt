namespace JC.LocationIngest.Models
{
    public sealed record JCRegisterRequest(string UserId, string Password, string? Email);
}
