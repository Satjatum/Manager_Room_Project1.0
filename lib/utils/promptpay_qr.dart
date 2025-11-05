// ยูทิลิตี้สำหรับสร้างสตริง EMVCo QR ของ PromptPay พร้อมจำนวนเงิน (Tag 54)
// อ้างอิงมาตรฐาน EMVCo และรูปแบบ PromptPay ไทย
// หมายเหตุ: โค้ดนี้สร้าง "สตริง" ของ QR เท่านั้น การแสดงผลรูปภาพใช้แพ็กเกจ qr_flutter ใน UI

class PromptPayQR {
  // แปลงหมายเลขตามประเภทให้เป็นรูปแบบที่ระบบพร้อมเพย์ต้องการ
  // - mobile: แปลง 0xxxxxxxxx -> 66xxxxxxxxx และเอาเฉพาะตัวเลข
  // - citizen_id / tax_id / ewallet: เอาเฉพาะตัวเลขตามที่ได้รับมา
  static String normalizeId(String type, String id) {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (type == 'mobile') {
      if (digits.startsWith('0')) {
        return '66${digits.substring(1)}';
      }
      // ถ้าผู้ใช้ป้อน 66xxxx มาแล้ว ก็ใช้เลย
      return digits;
    }
    return digits;
  }

  // Helper: เข้ารหัสฟิลด์แบบ EMV id+len+value (len เป็น 2 หลัก)
  static String _emv(String id, String value) {
    final len = value.length.toString().padLeft(2, '0');
    return '$id$len$value';
  }

  // คำนวณ CRC16-CCITT (0x1021) เริ่มต้น 0xFFFF
  static String _crc16(String data) {
    int crc = 0xFFFF;
    for (int i = 0; i < data.length; i++) {
      crc ^= data.codeUnitAt(i) << 8;
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }
        crc &= 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  // สร้างสตริง QR PromptPay แบบ dynamic (มีจำนวนเงิน)
  // type: 'mobile' | 'citizen_id' | 'tax_id' | 'ewallet'
  // id: หมายเลขตามประเภท (จะถูก normalize ให้เหลือตัวเลขและแปลง 0 -> 66 กรณีมือถือ)
  // amount: จำนวนเงิน ถ้า <= 0 จะไม่ใส่ Tag 54 (จะกลายเป็น static)
  // merchantName: ชื่อผู้รับเงิน (แสดงในข้อมูล QR บางแอป), ไม่บังคับ
  static String buildPayload({
    required String type,
    required String id,
    required double amount,
    String merchantName = 'Merchant',
  }) {
    final acct = normalizeId(type, id);

    // 00 Payload Format Indicator = "01"
    final f00 = _emv('00', '01');
    // 01 Point of Initiation Method: '12' = dynamic (มีจำนวนเงิน), '11' = static (ไม่มีจำนวนเงิน)
    final f01 = _emv('01', amount > 0 ? '12' : '11');

    // 29 Merchant Account Information (PromptPay)
    //   00 AID: A000000677010111
    //   01 Account (หมายเลขพร้อมเพย์ที่ normalize แล้ว)
    final mai = _emv('00', 'A000000677010111') + _emv('01', acct);
    final f29 = _emv('29', mai);

    // 52 Merchant Category Code: 0000 (ทั่วไป)
    final f52 = _emv('52', '0000');
    // 53 Transaction Currency: THB = 764
    final f53 = _emv('53', '764');
    // 54 Transaction Amount (ถ้ามากกว่า 0 ให้ใส่)
    final f54 = amount > 0 ? _emv('54', amount.toStringAsFixed(2)) : '';
    // 58 Country Code: TH
    final f58 = _emv('58', 'TH');
    // 59 Merchant Name (ใส่ชื่อย่อๆ)
    final name = (merchantName.isEmpty ? 'Merchant' : merchantName);
    final short = name.length > 25 ? name.substring(0, 25) : name;
    final f59 = _emv('59', short);

    // ต่อข้อมูลทั้งหมด และปิดท้ายด้วย 63 ความยาว 04 เพื่อเตรียมคำนวณ CRC
    final partial = f00 + f01 + f29 + f52 + f53 + f54 + f58 + f59 + '6304';
    final crc = _crc16(partial);
    return partial + crc;
  }
}
