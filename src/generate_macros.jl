## Julia script to generate the generated_macros.p4 macros

function generate_repeat_macros(max_n=2048)
  ret = "#define _REPEAT_3(macro) macro(8,null)\n"
  for k in 4:Int(log2(max_n))
    n = 2^k
    prec_n = 2^(k-1)
    ret *= "#define _REPEAT_$k(macro) macro($n,$prec_n) _REPEAT_$(k-1)(macro)\n"
  end
  return ret
end

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
  # n_key_max = 256
  # size_key  = 384
  # n_val_max = 1024
  # size_val  = 2040
  n_key_max = 64
  size_key  = 120
  n_val_max = 128
  size_val  = 248
  k_key_max = Int(log2(n_key_max))
  k_val_max = Int(log2(n_val_max))
  open(file, "w") do f
    println(f, generate_repeat_macros(max(n_key_max, n_val_max)))
    println(f, """
    #define _REPEAT_KEY(macro) _REPEAT_$k_key_max(macro)
    #define _REPEAT_VALUE(macro) _REPEAT_$k_val_max(macro)

    #define PARSE_KEY_TOP parse_key_$n_key_max
    #define PARSE_VALUE_TOP parse_value_$n_val_max

    #define INTERNAL_KEY_SIZE $size_key
    #define INTERNAL_VALUE_SIZE $size_val
    """)
    println(f, generate_parse_extract("key", "hdr.memcached.key_length", size_key, n_key_max))
    println(f, generate_parse_extract("value", "user_metadata.value_size", size_val, n_val_max))
    println(f, generate_repopulate_value(n_val_max))
  end
end
