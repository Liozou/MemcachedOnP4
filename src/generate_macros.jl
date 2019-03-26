## Julia script to generate the generated_macros.p4 macros


function generate_parse_extract(key_or_value="key", length="hdr.memcached.key_length", max_size=384, max_n=256)
  ret = "#define _PARSE_$(uppercase(key_or_value)) "
  max_k = Int(log2(max_n))
  for k in 3:max_k # The 3-offset comes from the fact that sizes are expressed in bytes
    n = 2^k
    next = k==3 ? "null" : string(2^(k-1))
    bit_size = 0

    if k!=max_k
      for i in 1:(2^(max_k-k)-1)
        if n+(i<<(k+1)) <= max_size
          bit_size = i<<(k+1)
        end
      end
    end

    size = bit_size==0 ? "" : "((bit<$bit_size>)user_metadata.$(key_or_value)) ++ "
    ret *= join(split("""
    state parse_extract_$(key_or_value)_$n {
      buffer.extract(hdr.$(key_or_value)_$n);
      user_metadata.$(key_or_value) = (bit<$max_size>)($(size)hdr.$(key_or_value)_$n.$(key_or_value));
      digest_data.$(key_or_value)_hash = digest_data.$(key_or_value)_hash ^ ((bit<64>)(hdr.$(key_or_value)_$n.$(key_or_value)));
      transition parse_$(key_or_value)_$next;
    }

    state parse_$(key_or_value)_$n {
      transition select($length[$(k-3):$(k-3)]) {
        1 : parse_extract_$(key_or_value)_$n;
        _ : parse_$(key_or_value)_$next;
      }
    }
    """, '\n'), "\\\n")
  end
  return ret*'\n'
end

function generate_repopulate_value(max_n=1024)
  ret = "#define REPOPULATE_VALUE "
  max_k = Int(log2(max_n))
  for k in 3:max_k
    n = 2^k
    ret *= join(split("""
    if (user_metadata.value_size_out[$(k-3):$(k-3)] == 1) {
      hdr.value_$n.value = (bit<$n>)user_metadata.value;
      hdr.value_$n.setValid();
      $(k!=max_k ? "user_metadata.value = (user_metadata.value >> $k);" : "")
    }
    """, '\n'), "\\\n")
  end
  return ret*'\n'
end

function main(file)
  open(file, "w") do f
    println(f, generate_parse_extract("key", "hdr.memcached.key_length", 384, 256))
    println(f, generate_parse_extract("value", "user_metadata.value_size", 2040, 1024))
    println(f, generate_repopulate_value(1024))
  end
end
