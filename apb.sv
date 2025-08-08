module APB(PCLK, PRESETn, PSEL0, PADDR, PWDATA, PWRITE, PENABLE, PSTRB, PREADY, PRDATA,PSLVERR);
	input PCLK, PRESETn;
	input PWRITE, PENABLE, PSEL0;
	input[3:0]PSTRB;
	input[31:0]PWDATA,PADDR;
	output reg[31:0]PRDATA;
	output reg PREADY, PSLVERR;

//Memory block
reg[7:0] mem [100];
initial begin 
	PRDATA = 0;
	PREADY = 0;
	PSLVERR = 0;
end

always@(posedge PCLK) begin 
	if(PRESETn==0)begin
		//all output ports are becomes 0;
		PRDATA = 0;
		PREADY = 0;
		PSLVERR = 0;
	end 
	else begin 
		//Output ports  depend on input;
		//Check setup state
		if(PSEL0==1)begin//master requesting data trasfer with slave devices
			PREADY = 1;//Indicating slave is ready for data transfer
			if(PENABLE==1)begin//master sending valid address and data
				if(PADDR%4==0)begin
					if(PWRITE==1)begin
						mem[PADDR] = (PSTRB[0]==1)? PWDATA[7:0]: 8'h00;
						mem[PADDR+1] =(PSTRB[1]==1)? PWDATA[15:8]: 8'h00;
						mem[PADDR+2] = (PSTRB[2]==1)? PWDATA[23:16]: 8'h00;
						mem[PADDR+3] = (PSTRB[3]==1)? PWDATA[31:24]: 8'h00;
					end
					else begin//read operation
						PRDATA = {mem[PADDR+3],mem[PADDR+2],mem[PADDR+1],mem[PADDR]};
					end
				end
				else PSLVERR = 1;
			end
		end
	        else PREADY = 0;	
	end

end
endmodule

interface apb_inf(input bit PCLK);
	bit PSEL0, PRESETn,PWRITE,PSLVERR, PREADY, PENABLE;
	bit[31:0]PWDATA, PRDATA, PADDR;
	bit[3:0]PSTRB;
endinterface

class pkt;
	randc bit PSEL0, PRESETn, PWRITE, PENABLE;
	randc bit[31:0]PWDATA, PADDR;
	randc bit[31:0]PSTRB;
	constraint c1{
		PSTRB==4'b1111;
		PADDR==40;
		PENABLE==1;
		PSEL0==1;
		}
	endclass

class common;
	static mailbox mb = new();
	static virtual apb_inf vif;
endclass

class gen;
	pkt a;
	task t1();
		a = new();
		a.randomize with{PWRITE==1; PRESETn==1;};
		common::mb.put(a);
		a = new();
		a.randomize with{PWRITE==0; PRESETn==1;};
		common::mb.put(a);

	endtask
endclass

class bfm;
	pkt b;
	task t2();
		b = new();
		common::mb.get(b);
		common::vif.PSEL0 = b.PSEL0;
		common::vif.PRESETn = b.PRESETn;
		common::vif.PWRITE = b.PWRITE;
		common::vif.PENABLE = b.PENABLE;
		common::vif.PWDATA = b.PWDATA;
		common::vif.PADDR = b.PADDR;
		common::vif.PSTRB = b.PSTRB;
	endtask
endclass

module test;
	bit PCLK;
	gen c = new();
	bfm d = new();
	apb_inf pvif(PCLK);
	initial begin
		PCLK = 0;
		forever #5 PCLK = ~PCLK;
	end
	APB dut(.PCLK(pvif.PCLK), .PRESETn(pvif.PRESETn), .PWDATA(pvif.PWDATA), .PRDATA(pvif.PRDATA), .PWRITE(pvif.PWRITE), .PENABLE(pvif.PENABLE), .PSTRB(pvif.PSTRB), .PADDR(pvif.PADDR), .PSEL0(pvif.PSEL0), .PREADY(pvif.PREADY), .PSLVERR(pvif.PSLVERR));
	initial begin 
		common::vif = pvif;
		repeat(10) begin
			c.t1();
			d.t2();
		@(posedge PCLK);
		end
		$finish;
	end
	endmodule
