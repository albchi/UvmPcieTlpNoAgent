// Top-level UVM testbench for random PCIe TLP generation

`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

// -------------------
// PCIe TLP Packet Definition
// -------------------
typedef enum {MEM_RD, MEM_WR, CFG_RD, CFG_WR, CPL, CPLD} tlp_type_e;

class pcie_tlp_packet extends uvm_sequence_item;
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit [15:0] requester_id;
  rand bit [9:0] tag;
  int cmd_seq = 0;
  rand tlp_type_e tlp_type; // renamed from 'type' to 'tlp_type'

  constraint c_type { tlp_type inside {MEM_RD, MEM_WR, CFG_RD, CFG_WR, CPL, CPLD}; }
  constraint c_addr { addr[1:0] == 2'b00; } // aligned to 4 bytes
  constraint c_data { data inside {[32'h0000_0000:32'hFFFF_FFFF]}; }
  constraint c_requester_id { requester_id inside {[16'h0000:16'hFFFF]}; }
  constraint c_tag { tag inside {[10'h0:10'h3FF]}; }

  `uvm_object_utils(pcie_tlp_packet)

  function new(string name="pcie_tlp_packet");
    super.new(name);
  endfunction

  function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("addr", addr, 32, UVM_HEX);
    printer.print_field("data", data, 32, UVM_HEX);
    printer.print_field("requester_id", requester_id, 16, UVM_HEX);
    printer.print_field("tag", tag, 10, UVM_DEC);
    printer.print_string("tlp_type", tlp_type.name());
  endfunction

endclass

// -------------------
// Sequence to Generate Random TLPs
// -------------------
class pcie_tlp_sequence extends uvm_sequence #(pcie_tlp_packet);
  `uvm_object_utils(pcie_tlp_sequence)

  function new(string name="pcie_tlp_sequence");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_packet pkt;
    repeat (10) begin
      pkt = pcie_tlp_packet::type_id::create("pkt");
      assert(pkt.randomize());
      `uvm_info("PCIE_TLP_SEQ", $sformatf("Generated TLP: %s", pkt.sprint()), UVM_MEDIUM)
      start_item(pkt);
      finish_item(pkt);
    end
  endtask
endclass

// -------------------
// Driver (prints out the TLPs)
// -------------------
class pcie_tlp_driver extends uvm_driver #(pcie_tlp_packet);
  `uvm_component_utils(pcie_tlp_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    pcie_tlp_packet pkt;
    forever begin
      seq_item_port.get_next_item(pkt);
      `uvm_info("PCIE_TLP_DRV", $sformatf("Driving TLP: %s", pkt.sprint()), UVM_MEDIUM)
      #123; //xac+ need to consume time to prove objection is needed
      seq_item_port.item_done();
    end
  endtask
endclass

// -------------------
// Environment
// -------------------
class pcie_tlp_env extends uvm_env;
  `uvm_component_utils(pcie_tlp_env)

  uvm_sequencer #(pcie_tlp_packet) sequencer;
  pcie_tlp_driver driver;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = uvm_sequencer#(pcie_tlp_packet)::type_id::create("sequencer", this);
    driver = pcie_tlp_driver::type_id::create("driver", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

// -------------------
// Test
// -------------------
class pcie_tlp_test extends uvm_test;
  `uvm_component_utils(pcie_tlp_test)

  pcie_tlp_env env;
  pcie_tlp_sequence seq; // xac+

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = pcie_tlp_env::type_id::create("env", this);
    seq = pcie_tlp_sequence::type_id::create("seq"); // xac+
  endfunction

  task run_phase(uvm_phase phase);
    // pcie_tlp_sequence seq; // xac-
    phase.raise_objection(this); // xac-
    // seq = pcie_tlp_sequence::type_id::create("seq"); // xac-
    seq.start(env.sequencer);
    phase.drop_objection(this); //xac=
  endtask
endclass


// -------------------
// Top Level Module
// -------------------



module tb_top;
  import uvm_pkg::*;
  initial begin
    $display("Start of simulation!"); // xac+
    run_test("pcie_tlp_test");
  end
endmodule
