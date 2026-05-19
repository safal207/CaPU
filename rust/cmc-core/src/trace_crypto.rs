use std::fmt::Write;

pub const GENESIS_SHA256: &str = "0000000000000000000000000000000000000000000000000000000000000000";

const K: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
    0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
    0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
    0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
    0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
    0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
    0xc67178f2,
];

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SealedTraceEvent {
    pub prev_hash: String,
    pub event: String,
    pub trace_hash: String,
}

fn ch(x: u32, y: u32, z: u32) -> u32 {
    (x & y) ^ (!x & z)
}

fn maj(x: u32, y: u32, z: u32) -> u32 {
    (x & y) ^ (x & z) ^ (y & z)
}

fn big_sigma0(x: u32) -> u32 {
    x.rotate_right(2) ^ x.rotate_right(13) ^ x.rotate_right(22)
}

fn big_sigma1(x: u32) -> u32 {
    x.rotate_right(6) ^ x.rotate_right(11) ^ x.rotate_right(25)
}

fn small_sigma0(x: u32) -> u32 {
    x.rotate_right(7) ^ x.rotate_right(18) ^ (x >> 3)
}

fn small_sigma1(x: u32) -> u32 {
    x.rotate_right(17) ^ x.rotate_right(19) ^ (x >> 10)
}

fn to_hex(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        write!(&mut out, "{byte:02x}").expect("writing to String cannot fail");
    }
    out
}

pub fn sha256_hex(input: &[u8]) -> String {
    let mut h = [
        0x6a09e667u32,
        0xbb67ae85,
        0x3c6ef372,
        0xa54ff53a,
        0x510e527f,
        0x9b05688c,
        0x1f83d9ab,
        0x5be0cd19,
    ];

    let bit_len = (input.len() as u64) * 8;
    let mut message = input.to_vec();
    message.push(0x80);
    while message.len() % 64 != 56 {
        message.push(0);
    }
    message.extend_from_slice(&bit_len.to_be_bytes());

    for chunk in message.chunks_exact(64) {
        let mut w = [0u32; 64];
        for idx in 0..16 {
            let start = idx * 4;
            w[idx] = u32::from_be_bytes([
                chunk[start],
                chunk[start + 1],
                chunk[start + 2],
                chunk[start + 3],
            ]);
        }
        for idx in 16..64 {
            w[idx] = small_sigma1(w[idx - 2])
                .wrapping_add(w[idx - 7])
                .wrapping_add(small_sigma0(w[idx - 15]))
                .wrapping_add(w[idx - 16]);
        }

        let mut a = h[0];
        let mut b = h[1];
        let mut c = h[2];
        let mut d = h[3];
        let mut e = h[4];
        let mut f = h[5];
        let mut g = h[6];
        let mut hh = h[7];

        for idx in 0..64 {
            let t1 = hh
                .wrapping_add(big_sigma1(e))
                .wrapping_add(ch(e, f, g))
                .wrapping_add(K[idx])
                .wrapping_add(w[idx]);
            let t2 = big_sigma0(a).wrapping_add(maj(a, b, c));
            hh = g;
            g = f;
            f = e;
            e = d.wrapping_add(t1);
            d = c;
            c = b;
            b = a;
            a = t1.wrapping_add(t2);
        }

        h[0] = h[0].wrapping_add(a);
        h[1] = h[1].wrapping_add(b);
        h[2] = h[2].wrapping_add(c);
        h[3] = h[3].wrapping_add(d);
        h[4] = h[4].wrapping_add(e);
        h[5] = h[5].wrapping_add(f);
        h[6] = h[6].wrapping_add(g);
        h[7] = h[7].wrapping_add(hh);
    }

    let mut digest = [0u8; 32];
    for (idx, word) in h.iter().enumerate() {
        digest[idx * 4..idx * 4 + 4].copy_from_slice(&word.to_be_bytes());
    }
    to_hex(&digest)
}

pub fn trace_hash(prev_hash: &str, event: &str) -> String {
    sha256_hex(format!("{prev_hash}{event}").as_bytes())
}

pub fn seal_trace(jsonl: &str) -> Vec<SealedTraceEvent> {
    let mut prev_hash = GENESIS_SHA256.to_string();
    let mut sealed = Vec::new();

    for line in jsonl.lines().filter(|line| !line.trim().is_empty()) {
        let event = line.to_string();
        let trace_hash = trace_hash(&prev_hash, &event);
        sealed.push(SealedTraceEvent {
            prev_hash,
            event,
            trace_hash: trace_hash.clone(),
        });
        prev_hash = trace_hash;
    }
    sealed
}

pub fn verify_trace(sealed: &[SealedTraceEvent]) -> Result<(), usize> {
    let mut prev_hash = GENESIS_SHA256.to_string();

    for (idx, event) in sealed.iter().enumerate() {
        if event.prev_hash != prev_hash {
            return Err(idx + 1);
        }
        let expected = trace_hash(&prev_hash, &event.event);
        if event.trace_hash != expected {
            return Err(idx + 1);
        }
        prev_hash = event.trace_hash.clone();
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sha256_matches_empty_vector() {
        assert_eq!(
            sha256_hex(b""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
    }

    #[test]
    fn sha256_matches_abc_vector() {
        assert_eq!(
            sha256_hex(b"abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn seal_and_verify_trace() {
        let sealed = seal_trace("event-one\nevent-two\n");
        assert_eq!(sealed.len(), 2);
        assert!(verify_trace(&sealed).is_ok());
    }

    #[test]
    fn detects_tampering() {
        let mut sealed = seal_trace("event-one\nevent-two\n");
        sealed[0].event = "event-tampered".to_string();
        assert_eq!(verify_trace(&sealed), Err(1));
    }
}
