## Julia script to generate the generated_macros.p4 macros

function generate_repeat_macros(max_k=11)
  ret = "#define _REPEAT_3(macro) macro(8,null)\n"
  for k in 4:max_k
    n = 2^k
    prec_n = 2^(k-1)
    ret *= "#define _REPEAT_$k(macro) macro($n,$prec_n) _REPEAT_$(k-1)(macro)\n"
  end
  return ret
end

function generate_parse_extract(key_or_value="key", length="hdr.memcached.key_length", store="digest_data", max_size=384, max_k=8, offset=0)
  ret = "#define _PARSE_$(uppercase(key_or_value)) "
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

    size = bit_size==0 ? "" : "$store.$key_or_value[$(bit_size-1):0] ++ "
    ret *= join(split("""
    state parse_extract_$(key_or_value)_$n {
      buffer.extract(hdr.$(key_or_value)_$n);
      $store.$key_or_value[$(bit_size+n-1):0] = $(size)hdr.$(key_or_value)_$n.$key_or_value;
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

function generate_repopulate_value(max_k=10, max_size=2040)
  ret = "#define REPOPULATE_VALUE "
  rev_counter = max_size-1
  for k in 3:max_k-2
    n = 2^k
    ret *= join(split("""
    if (digest_data.value_size_out[$(k-3):$(k-3)] == 1) {
      hdr.value_$n.setValid();
      hdr.value_$n.value = user_metadata.value[$(n-1):0];
      user_metadata.value[$(rev_counter-n):0] = user_metadata.value[$rev_counter:$n];
    }

    """, '\n'), "\\\n")
    rev_counter -= n
  end

  n = 2^(max_k-1)
  ret *= join(split("""
  if (digest_data.value_size_out[$(max_k-4):$(max_k-4)] == 1) {
    hdr.value_$n.setValid();
    hdr.value_$n.value = user_metadata.value[$(n-1):0];
    hdr.value_$(2^max_k).value = user_metadata.value[$rev_counter:$n];
  }

  """, '\n'), "\\\n")

  n = 2^max_k
  ret *= join(split("""
  if (digest_data.value_size_out[$(max_k-3):$(max_k-3)] == 1) {
    hdr.value_$n.setValid();
  }

  """, '\n'), "\\\n")

  return ret*'\n'
end

function main(file)
  # n_key_max = 256
  # size_key  = 384
  # n_val_max = 1024
  # size_val  = 2040
  n_key_max = 32
  size_key  = 128
  n_val_max = 128
  size_val  = 248
  k_key_max = Int(log2(n_key_max))
  k_val_max = Int(log2(n_val_max))
  open(file, "w") do f
    println(f, generate_repeat_macros(max(k_key_max, k_val_max)))
    println(f, """
    #define _REPEAT_KEY(macro) _REPEAT_$k_key_max(macro)
    #define _REPEAT_VALUE(macro) _REPEAT_$k_val_max(macro)

    #define PARSE_KEY_TOP parse_key_$n_key_max
    #define PARSE_VALUE_TOP parse_value_$n_val_max

    #define INTERNAL_VALUE_SIZE $(size_val+32)
    """)
    println(f, generate_parse_extract("key", "hdr.memcached.key_length", "digest_data", size_key, k_key_max))
    println(f, generate_parse_extract("value", "user_metadata.value_size", "user_metadata", size_val, k_val_max))
    println(f, generate_repopulate_value(k_val_max, size_val))
  end
end
