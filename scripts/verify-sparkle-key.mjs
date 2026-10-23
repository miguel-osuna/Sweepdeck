import assert from "node:assert/strict";
import { createPrivateKey, createPublicKey, timingSafeEqual } from "node:crypto";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

const ed25519PKCS8Prefix = Buffer.from("302e020100300506032b657004220420", "hex");

function decodeCanonicalBase64(value, label) {
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(value)) {
    throw new Error(`${label} is not canonical base64.`);
  }
  const decoded = Buffer.from(value, "base64");
  if (decoded.toString("base64") !== value) {
    throw new Error(`${label} is not canonical base64.`);
  }
  return decoded;
}

export function deriveSparklePublicKey(privateSeed) {
  if (privateSeed.length !== 32) {
    throw new Error(`Sparkle's EdDSA private seed must be 32 bytes; got ${privateSeed.length}.`);
  }
  const privateKey = createPrivateKey({
    key: Buffer.concat([ed25519PKCS8Prefix, privateSeed]),
    format: "der",
    type: "pkcs8",
  });
  const publicDER = createPublicKey(privateKey).export({ format: "der", type: "spki" });
  return publicDER.subarray(-32);
}

export function deriveSparklePublicKeyFromBase64(privateBase64) {
  if (!privateBase64.trim()) {
    throw new Error("SPARKLE_EDDSA_PRIVATE_KEY is empty.");
  }
  const privateSeed = decodeCanonicalBase64(privateBase64.trim(), "Sparkle private key");
  return deriveSparklePublicKey(privateSeed).toString("base64");
}

export function verifySparkleKeyPair(privateBase64, publicBase64) {
  if (!privateBase64.trim()) {
    throw new Error("SPARKLE_EDDSA_PRIVATE_KEY is empty in the protected release environment.");
  }
  const expectedPublicKey = decodeCanonicalBase64(publicBase64.trim(), "Embedded Sparkle public key");
  if (expectedPublicKey.length !== 32) {
    throw new Error(`The embedded Sparkle public key must be 32 bytes; got ${expectedPublicKey.length}.`);
  }
  const actualPublicKey = Buffer.from(deriveSparklePublicKeyFromBase64(privateBase64), "base64");
  if (!timingSafeEqual(actualPublicKey, expectedPublicKey)) {
    throw new Error("The release signing key does not match SUPublicEDKey in Resources/Info.plist.");
  }
}

export function runSelfTest() {
  // RFC 8032 test vector 1 verifies the raw-seed-to-public-key conversion.
  const seed = Buffer.from("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60", "hex");
  const expected = Buffer.from("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a", "hex");
  assert.deepEqual(deriveSparklePublicKey(seed), expected);
  verifySparkleKeyPair(seed.toString("base64"), expected.toString("base64"));
  assert.throws(
    () => verifySparkleKeyPair(seed.toString("base64"), Buffer.alloc(32).toString("base64")),
    /does not match SUPublicEDKey/,
  );
}

runSelfTest();

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  if (process.argv[2] === "--self-test") {
    console.log("Sparkle EdDSA key derivation test passed.");
  } else if (process.argv[2] === "--print-public") {
    try {
      console.log(deriveSparklePublicKeyFromBase64(process.env.SPARKLE_EDDSA_PRIVATE_KEY ?? ""));
    } catch (error) {
      console.error(error instanceof Error ? error.message : "Sparkle public key derivation failed.");
      process.exitCode = 1;
    }
  } else {
    try {
      verifySparkleKeyPair(
        process.env.SPARKLE_EDDSA_PRIVATE_KEY ?? "",
        process.env.SPARKLE_EDDSA_PUBLIC_KEY ?? "",
      );
      console.log("Sparkle release key matches the embedded public key.");
    } catch (error) {
      console.error(error instanceof Error ? error.message : "Sparkle signing key validation failed.");
      process.exitCode = 1;
    }
  }
}
