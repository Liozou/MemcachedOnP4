//
// Copyright (c) 2017 Stephen Ibanez
// All rights reserved.
//
// This software was developed by Stanford University and the University of Cambridge Computer Laboratory
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"),
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//


/*
 * File: @MODULE_NAME@.v
 * Author: Stephen Ibanez
 *
 * Modified by Lionel Zoubritzky
 *
 * Hand modified auto-generated file.
 *
 * reg_dataRW
 *
 * Atomically read or write a register without control plane interface.
 *
 */



`timescale 1 ps / 1 ps
`define READ_OP    8'd0
`define WRITE_OP   8'd1


module @MODULE_NAME@
#(
    parameter INDEX_WIDTH = @INDEX_WIDTH@,
    parameter REG_WIDTH = @REG_WIDTH@,
    parameter OP_WIDTH = 8,
    parameter INPUT_WIDTH = REG_WIDTH+INDEX_WIDTH+8+1
)
(
    // Data Path I/O
    input                                           clk_lookup,
    input                                           rst,
    input                                           tuple_in_@EXTERN_NAME@_input_VALID,
    input   [INPUT_WIDTH-1:0]                       tuple_in_@EXTERN_NAME@_input_DATA,
    output                                          tuple_out_@EXTERN_NAME@_output_VALID,
    output  [REG_WIDTH-1:0]                         tuple_out_@EXTERN_NAME@_output_DATA
);


/* Tuple format for input:
        [REG_WIDTH+INDEX_WIDTH+8   : REG_WIDTH+INDEX_WIDTH+8] : statefulValid
        [REG_WIDTH+INDEX_WIDTH+7   : REG_WIDTH+8            ] : index_in
        [REG_WIDTH+7               : 8                        ] : newVal_in
        [7                         : 0                        ] : opCode_in
*/

    // request_fifo output signals
    wire                           statefulValid_fifo;
    wire    [INDEX_WIDTH-1:0]      index_fifo;
    wire    [REG_WIDTH-1:0]        newVal_fifo;
    wire    [OP_WIDTH-1:0]         opCode_fifo;

    wire empty_fifo;
    wire full_fifo;
    reg rd_en_fifo;

    localparam L2_REQ_BUF_DEPTH = 6;
    localparam REG_DEPTH = 2**INDEX_WIDTH;

    // data plane state machine states
    localparam START_REQ = 0;
    localparam WAIT_BRAM = 1;
    localparam WRITE_RESULT = 2;

    // data plane state machine signals
    reg [2:0]                     d_state, d_state_next;
    reg [REG_WIDTH-1:0]           result_r, result_r_next;
    reg [1:0]                     cycle_cnt, cycle_cnt_next;
    reg                           valid_out;
    reg [REG_WIDTH-1:0]           result_out;

    // BRAM signals
    reg                      d_we_bram;
    reg                      d_en_bram;
    reg  [INDEX_WIDTH-1:0]   d_addr_in_bram, d_addr_in_bram_r, d_addr_in_bram_r_next;
    reg  [REG_WIDTH-1:0]     d_data_in_bram;
    wire [REG_WIDTH-1:0]     d_data_out_bram;


    //// Input buffer to hold requests ////
    fallthrough_small_fifo
    #(
        .WIDTH(INPUT_WIDTH),
        .MAX_DEPTH_BITS(L2_REQ_BUF_DEPTH)
    )
    request_fifo
    (
       // Outputs
       .dout                           ({statefulValid_fifo, index_fifo, newVal_fifo, opCode_fifo}),
       .full                           (full_fifo),
       .nearly_full                    (),
       .prog_full                      (),
       .empty                          (empty_fifo),
       // Inputs
       .din                            (tuple_in_@EXTERN_NAME@_input_DATA),
       .wr_en                          (tuple_in_@EXTERN_NAME@_input_VALID),
       .rd_en                          (rd_en_fifo),
       .reset                          (rst),
       .clk                            (clk_lookup)
    );

    //// BRAM to hold state ////
    true_sp_bram
    #(
        .L2_DEPTH(INDEX_WIDTH),
        .WIDTH(REG_WIDTH)
    ) @PREFIX_NAME@_bram
    (
        .clk               (clk_lookup),
        // data plane R/W interface
        .we2               (d_we_bram),
        .en2               (d_en_bram),
        .addr2             (d_addr_in_bram),
        .din2              (d_data_in_bram),
        .rst2              (rst),
        .regce2            (d_en_bram),
        .dout2             (d_data_out_bram)
    );

   /* data plane R/W State Machine */
   always @(*) begin
      // default values
      d_state_next   = d_state;
      rd_en_fifo = 0;
      d_en_bram = 1;

      d_we_bram = 0;
      d_addr_in_bram = d_addr_in_bram_r;
      d_addr_in_bram_r_next = d_addr_in_bram_r;
      d_data_in_bram = 0;

      result_r_next = result_r;

      cycle_cnt_next = cycle_cnt;
      valid_out = 0;
      result_out = 0;

      case(d_state)
          START_REQ: begin
              if (~empty_fifo) begin
                  rd_en_fifo = 1;
                  if (statefulValid_fifo && index_fifo < REG_DEPTH) begin
                      if (opCode_fifo == `READ_OP) begin
                          d_addr_in_bram = index_fifo;
                          d_addr_in_bram_r_next = index_fifo;
                          d_state_next = WAIT_BRAM;
                      end
                      else if (opCode_fifo == `WRITE_OP) begin
                          d_we_bram = 1;
                          d_addr_in_bram = index_fifo;
                          d_addr_in_bram_r_next = index_fifo;
                          d_data_in_bram = newVal_fifo;
                          result_r_next = newVal_fifo;
                          d_state_next = WRITE_RESULT;
                      end
                      else begin
                          $display("ERROR: d_state = START_REQ, unsupported opCode: %0d\n", opCode_fifo);
                          result_r_next = 0;
                          d_state_next = WRITE_RESULT;
                      end
                  end
                  else begin
                      result_r_next = 0;
                      d_state_next = WRITE_RESULT;
                  end
              end
          end

          WAIT_BRAM: begin
              if (cycle_cnt == 1'b1) begin // 2 cycle BRAM read latency
                  cycle_cnt_next = 0;
                  result_r_next = d_data_out_bram;
                  d_state_next = WRITE_RESULT;
              end
              else begin
                  cycle_cnt_next = cycle_cnt + 1;
              end
          end

          WRITE_RESULT: begin
             valid_out = 1;
             result_out = result_r;
             d_state_next = START_REQ;
          end
      endcase // case(d_state)
   end // always @ (*)

   assign tuple_out_@EXTERN_NAME@_output_VALID = valid_out;
   assign tuple_out_@EXTERN_NAME@_output_DATA  = result_out;

   always @(posedge clk_lookup) begin
      if(rst) begin
         d_state <= START_REQ;
         d_addr_in_bram_r <= 0;
         result_r <= 0;
         cycle_cnt <= 0;
      end
      else begin
         d_state <= d_state_next;
         d_addr_in_bram_r <= d_addr_in_bram_r_next;
         result_r <= result_r_next;
         cycle_cnt <= cycle_cnt_next;
      end
   end

endmodule
