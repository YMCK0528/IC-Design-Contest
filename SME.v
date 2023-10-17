module SME(clk,reset,chardata,isstring,ispattern,valid,match,match_index);
input clk;
input reset;
input [7:0] chardata;
input isstring;
input ispattern;
output match;
output [4:0] match_index;
output valid;

reg match,valid;
reg [4:0] match_index;
reg [5:0] index_s;
reg [4:0] index_p,index_p_temp;
reg [4:0] cnt_m,cnt_m_temp; //match counter

reg [2:0] current_state,next_state,cs_p,ns_p;//狀態
reg [7:0] string_reg [0:31];
reg [5:0] cnt_s; //string counter
reg [7:0] pattern_reg [0:7];
reg [4:0] cnt_p; // pattern counter
reg done; //process done flag
reg star_flag;

//debug
wire [7:0] s_debug = string_reg[index_s];
wire [7:0] p_debug = pattern_reg[index_p];
wire [7:0] p_debug_head = pattern_reg[index_p+5'd1];

parameter IDLE = 3'd0;
parameter RECV_S = 3'd1; //receive string
parameter RECV_P = 3'd2; //receive pattern
parameter PROCESS = 3'd3;
parameter DONE = 3'd4;

parameter P_IDLE = 3'd0;
parameter CHECK = 3'd1;
parameter CHECK_MATCH = 3'd2;
parameter P_DONE_MATCH = 3'd3;
parameter P_DONE_UNMATCH = 3'd4; //unmatch
//state switch
always@(posedge clk or posedge reset)
begin//當觸發時，如果有reset，cs進入IDEL，cs_p進入P_IDEL，否則cs進入ns，cs_p進入ns_p
    if(reset)
    begin
        current_state <= IDLE;
        cs_p <= P_IDLE;
    end
    else
    begin
        current_state <= next_state;
        cs_p <= ns_p;
    end
end

//next state logic
always@(*)
begin//當觸發時
    case(current_state)
        IDLE:
        begin
            if(isstring == 1'd1)
                next_state = RECV_S;//如果isstring信號等於1，ns = RECV_S
            else if(ispattern == 1'd1)
                next_state = RECV_P;//如果ispattern信號等於1，ns = RECV_P
            else
                next_state = IDLE;//否則ns = IDLE
        end
        RECV_S:
        begin
            if(isstring == 1'd1)
                next_state = RECV_S;//如果isstring信號等於1，ns = RECV_S
            else
                next_state = RECV_P;//否則ns =  RECV_P
        end
        RECV_P:
        begin
            if(ispattern == 1'd1)
                next_state = RECV_P;//如果isstring信號等於1，ns = RECV_P
            else
                next_state = PROCESS;//否則ns =  PROCESS
        end
        PROCESS:
        begin
            if(done == 1'd1)
                next_state = DONE;//如果done信號等於1，ns = DONE(結束)
            else
                next_state = PROCESS;//否則ns =  PROCESS
        end
        DONE:
        begin//重新抓訊號
            if(isstring == 1'd1)
                next_state = RECV_S;
            else if(ispattern == 1'd1)
                next_state = RECV_P;
            else
                next_state = IDLE;
        end
        default:
            next_state = IDLE;
    endcase
end

always@(*)
begin
    if(current_state == PROCESS)
    begin//如果信號ispattern=0了
        case(cs_p)
            P_IDLE:
            begin
                ns_p = CHECK;
            end
            CHECK:
            begin
                if(cnt_m == cnt_p)
                    ns_p = P_DONE_MATCH;//比完跳結束
                else if(cnt_s == index_s || cnt_p == index_p)
                    ns_p = CHECK_MATCH;//如果index_s or index_p
                else
                    ns_p = CHECK;
            end
            CHECK_MATCH:
            begin
                if(pattern_reg[cnt_p-5'd1] == 8'h24)//如果是$
                begin
                    if(cnt_m+5'd1 == cnt_p)
                        ns_p = P_DONE_MATCH;
                    else
                        ns_p = P_DONE_UNMATCH;
                end
                else
                begin
                    if(cnt_m == cnt_p)
                        ns_p = P_DONE_MATCH;
                    else
                        ns_p = P_DONE_UNMATCH;
                end
            end
            P_DONE_MATCH:
                ns_p = P_IDLE;
            P_DONE_UNMATCH:
                ns_p = P_IDLE;
            default:
                ns_p = P_IDLE;
        endcase
    end
    else
        ns_p = P_IDLE;
end

//output logic
always@(posedge clk or posedge reset)
begin
    if(reset)
    begin
        index_s <= 6'd0;
        index_p <= 5'd0;
        index_p_temp <= 5'd0;
        cnt_m <= 5'd0;
        cnt_m_temp <= 5'd0;
        match_index <= 5'd0;
        done <= 1'd0;
        star_flag <= 1'd0;
    end
    else if(current_state == DONE)
    begin
        index_s <= 6'd0;
        index_p <= 5'd0;
        index_p_temp <= 5'd0;
        cnt_m <= 5'd0;
        cnt_m_temp <= 5'd0;
        match_index <= 5'd0;
        done <= 1'd0;
        star_flag <= 1'd0;
    end
    else if(current_state == PROCESS)
    begin
        if(cs_p == CHECK)
        begin
            if(string_reg[index_s] == pattern_reg[index_p] || pattern_reg[index_p] == 8'h2e)//如果第一個字一樣或是.
            begin
                index_p <= index_p + 5'd1;
                index_s <= index_s + 6'd1;
                cnt_m <= cnt_m + 5'd1;
                if(index_p == 5'd0)//
                    match_index <= index_s;
            end
            else if(pattern_reg[index_p] == 8'h5e) //special pattern ^
            begin
                if(index_s == 6'd0 && (string_reg[index_s] == pattern_reg[index_p+5'd1] || pattern_reg[index_p+5'd1] == 8'h2e) )
                begin
                    index_p <= index_p + 5'd1;
                    index_s <= index_s + 6'd1;
                    cnt_m <= cnt_m + 5'd1;
                    if(string_reg[index_s] == 8'h20)
                        match_index <= index_s + 6'd1;
                    else
                        match_index <= index_s;
                end
                else if(string_reg[index_s] == 8'h20 && (string_reg[index_s+5'd1] == pattern_reg[index_p+5'd1] || pattern_reg[index_p+5'd1] == 8'h2e) )
                begin
                    index_p <= index_p + 5'd1;
                    index_s <= index_s + 6'd1;
                    cnt_m <= cnt_m + 5'd1;
                    if(string_reg[index_s] == 8'h20)
                        match_index <= index_s + 6'd1;
                    else
                        match_index <= index_s;
                end
                else
                begin
                    index_p <= index_p_temp;
                    cnt_m <= 5'd0;
                    if(index_p != 5'd0)
                        index_s <= match_index + 6'd1;
                    else
                        index_s <= index_s + 6'd1;
                end
            end
            else if(pattern_reg[index_p] == 8'h24 && (index_s == cnt_s || string_reg[index_s] == 8'h20))
            begin //special pattern $
                index_p <= index_p + 5'd1;
                index_s <= index_s + 6'd1;
                cnt_m <= cnt_m + 5'd1;
                if(index_p == 5'd0)
                    match_index <= index_s;
            end
            else if(pattern_reg[index_p] == 8'h2A)
            begin //special pattern *
                star_flag <= 1'd1;
                index_p <= index_p + 5'd1;
                index_p_temp <= index_p + 5'd1;
                index_s <= index_s;
                cnt_m <= cnt_m + 5'd1;
                cnt_m_temp <= cnt_m + 5'd1;
                if(index_p == 5'd0)
                    match_index <= index_s;
            end
            else if(star_flag == 1'd1 && string_reg[index_s] != pattern_reg[index_p] && pattern_reg[index_p] != 8'h2e)
            begin
                index_p <= index_p_temp;
                cnt_m <= cnt_m_temp;
                index_s <= index_s + 6'd1;
            end
            else if(string_reg[index_s] != pattern_reg[index_p] && pattern_reg[index_p] != 8'h2e)
            begin
                index_p <= index_p_temp;
                cnt_m <= 5'd0;
                if(index_p != 5'd0)
                    index_s <= match_index + 6'd1;
                else
                    index_s <= index_s + 6'd1;
            end
        end
        else if(cs_p == P_DONE_MATCH || cs_p == P_DONE_UNMATCH)
        begin
            done <= 1'd1;
        end
    end
    else
    begin
        done <= 1'd0;
    end
end
//----------------------------------------------------------------------------------------------------
//match
always@(posedge clk or posedge reset)
begin
    if(reset)
        match <= 1'd0;
    else if(ns_p == P_DONE_MATCH)
        match <= 1'd1;
    else if(ns_p == P_DONE_UNMATCH)
        match <= 1'd0;
end

//valid
always@(posedge clk or posedge reset)
begin
    if(reset)
        valid <= 1'd0;
    else if(next_state == DONE)
        valid <= 1'd1;
    else
        valid <= 1'd0;
end

//string_reg
integer  i;
always@(posedge clk or posedge reset)
begin
    if(reset)
    begin
        for(i=0;i<32;i=i+1)
        begin
            string_reg[i] <= 8'd0;
        end
    end
    else if(current_state == DONE && next_state == RECV_S)
        string_reg[5'd0] <= chardata;//抓下一筆string時，回到第0個位置開始放
    else if(isstring == 1'd1)
        string_reg[cnt_s] <= chardata;
end

//string counter
reg [5:0] cnt_s_reg;
always@(*)
begin
    if(current_state == DONE && next_state == RECV_S)
        cnt_s = 6'd0;//如果cs == DONE && next_state == RECV_S，就把cnt_s清0
    else if(current_state  == IDLE && next_state == RECV_S)
        cnt_s = 6'd0;
    else if(isstring == 1'd1)
        cnt_s = cnt_s_reg + 6'd1;
    else
        cnt_s = cnt_s_reg;
end

always@(posedge clk or posedge reset)
begin
    if(reset)
        cnt_s_reg <= 6'd0;
    //else if(current_state == DONE && next_state == RECV_S) cnt_s_reg <= 6'd0;
    else if(isstring == 1'd1)
        cnt_s_reg <= cnt_s;//不然isstring=1，就會把cnt_s丟進去cnt_s_reg
end

//pattern_reg
always@(posedge clk or posedge reset)
begin
    if(reset)
    begin
        for(i=0;i<8;i=i+1)
        begin
            pattern_reg[i] <= 8'd0;//如果reset就會把I清光
        end
    end
    else if(ispattern == 1'd1)
        pattern_reg[cnt_p] <= chardata;//不然ispattern=1，就會把chardata丟進去cnt_p的位置
end

//pattern counter
always@(posedge clk or posedge reset)
begin
    if(reset)
        cnt_p <= 5'd0;//如果reset就會清0
    else if(ispattern == 1'd1)
        cnt_p <= cnt_p + 5'd1;//不然ispattern=1，就會開始數，一個cloclk數一次
    else if(next_state == DONE)
        cnt_p <= 5'd0;//當作完的時候，也清為0
end

endmodule
