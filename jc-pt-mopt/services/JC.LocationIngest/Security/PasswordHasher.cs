using System.Security.Cryptography;

namespace JC.LocationIngest.Security;

public static class PasswordHasher
{
    // Genera salt base64
    public static string GenerateSalt(int size = 16)
    {
        var bytes = RandomNumberGenerator.GetBytes(size);
        return Convert.ToBase64String(bytes);
    }

    // Hash PBKDF2 base64
    public static string HashPassword(string password, string saltBase64, int iterations = 100_000, int keySize = 32)
    {
        var salt = Convert.FromBase64String(saltBase64);

        using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, iterations, HashAlgorithmName.SHA256);
        var key = pbkdf2.GetBytes(keySize);

        return Convert.ToBase64String(key);
    }

    public static bool Verify(string password, string saltBase64, string expectedHashBase64)
    {
        var hash = HashPassword(password, saltBase64);
        // comparación segura
        return CryptographicOperations.FixedTimeEquals(
            Convert.FromBase64String(hash),
            Convert.FromBase64String(expectedHashBase64)
        );
    }
}
