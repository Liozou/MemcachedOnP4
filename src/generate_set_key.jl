## Julia script to generate the set_key.p4 file

function generate_key(spacelevel, counter, level, prefix)
  @assert level >= 0
  space = "  "^(spacelevel-level)
  if level==0
    return """
$(space)if (hdr.key_0.isValid()) {
$space    user_metadata.key = $(counter)w0$prefix ++ hdr.key_0.key;
$space  } else {
$space    user_metadata.key = $(counter+1)w0$prefix;
$space  }"""
  else
    return """
$(space)if (hdr.key_$level.isValid()) {
  $(generate_key(spacelevel, counter, level-1, "$prefix ++ hdr.key_$level.key"))
$space  } else {
  $(generate_key(spacelevel, counter+2^level, level-1, prefix))
$space  }"""
  end
end

function main(file)
  open(file, "w") do f
    println(f, """
control SetKey(inout headers hdr,
               inout user_metadata_t user_metadata) {

apply {
  if (hdr.key_8.isValid()) {
    if (hdr.key_7.isValid()) {
      user_metadata.key = hdr.key_8.key ++ hdr.key_7.key;
    } else {
$(generate_key(9, 1, 6, " ++ hdr.key_8.key"))
    }

  } else {

$(generate_key(9, 129, 7, ""))

  }
 }
}
""")
  end
end
