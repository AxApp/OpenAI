//
//  EncoderTests.swift
//  
//
//  Created by linhey on 2023/4/3.
//

import XCTest
import OpenAI

final class EncoderTests: XCTestCase {
    
    
    func test_empty_string() {
        let encoder = OpenAI.Tokenizer()
        let str = ""
        assert(encoder.encode(str) == [])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_space() {
        let encoder = OpenAI.Tokenizer()
        let str = " "
        assert(encoder.encode(str) == [220])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_tab() {
        let encoder = OpenAI.Tokenizer()
        let str = "\t"
        assert(encoder.encode(str) == [197])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_simple_text() {
        let encoder = OpenAI.Tokenizer()
        let str = "This is some text"
        assert(encoder.encode(str) == [1212, 318, 617, 2420])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_multi_token_word() {
        let encoder = OpenAI.Tokenizer()
        let str = "indivisible"
        assert(encoder.encode(str) == [521, 452, 12843])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_emojis() {
        let encoder = OpenAI.Tokenizer()
        let str = "hello 👋 world 🌍"
        assert(encoder.encode(str) == [31373, 50169, 233, 995, 12520, 234, 235])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_properties_of_Object() {
        let encoder = OpenAI.Tokenizer()
        let str = "toString constructor hasOwnProperty valueOf"
        assert(encoder.encode(str) == [1462, 10100, 23772, 468, 23858, 21746, 1988, 5189])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_long_test() {
        let str = """
感谢 @暨南大学附属祈福医院（广东祈福医院）耳鼻喉解剖实验室 武俊男 分享的病例： 【病例介绍】 患者：女，38岁。 主诉：反复右眼溢泪10余年，右侧鼻塞1个月。 现病史：患者于10余年前无明显诱因出现右眼反复溢泪，无流脓，无鼻塞、流涕，无疼痛、无眼周皮肤发红及血泪症状，未诊治。于1个月前无明显诱因出现右侧鼻塞，右侧面部胀痛，偶有涕中带血，无流脓涕就诊。 查体：右侧鼻旁泪囊区可触及中等硬度肿物，边界尚清，眼球运动正常，双裸眼视力1.0。 辅助检查： 1.鼻内镜：右侧鼻腔总鼻道可见淡红色新生物，表面呈分叶状，探查新生物来源于右侧下鼻道及鼻底（图1）。 图1：→ 鼻腔及下鼻道肿瘤  2.鼻窦CT：右侧泪囊区、鼻泪管内见占位性病变，呈膨胀性生长，密度稍增高（标识①）、右侧鼻腔底部异常软组织影（标识②）。 3、鼻窦MRI：右侧泪囊区域及鼻泪管内可见卵圆形稍长T1、T2信号，增强扫描明显强化，病变位于肌锥外间隙，边界清楚。 T1WI水平位 T2WI冠状位 T1W冠状位增强 4. 鼻腔新生物活检：病理报告为内翻性乳头状瘤。 诊断：右侧鼻腔及泪囊鼻泪管内翻性乳头状瘤 手术方案：经鼻内镜改良泪前隐窝径路联合经眶径路切除鼻腔泪囊内翻性乳头状瘤切除术 手术经过： A.改良泪前隐窝径路：鼻内镜下定位下鼻甲头端和鼻内孔交界处，于中鼻甲腋部上方10mm、前方10mm处起始，沿鼻腔外侧壁经下鼻甲头端至鼻底做弧形切口，切开粘膜，翻起粘膜瓣，充分显露下鼻甲鼻腔外侧壁骨性附着处。 B.暴露鼻泪管：离断下鼻甲骨鼻腔外侧壁附着处；以附着点为标志，用骨凿解剖鼻泪管；用电钻磨开骨性鼻泪管，磨除部分上颌骨额突，充分暴露膜性鼻泪管及部分泪囊，可见膜性鼻泪管显著扩张，增粗，自下向上钝性分离鼻泪管及泪囊下部。 C.经眶外径路：沿下眼睑皮肤纹理方向，于下睑缘下方3mm处做弧形皮肤切口，长度约2cm。分离皮下组织，暴露泪囊上段，见泪囊明显膨胀，肿瘤未突破泪囊外壁。 D.切除病灶：切除鼻腔前端及下鼻道前端肿瘤，沿鼻泪管分离，上下切口沟通后切断泪小管，完整切除泪囊及鼻泪管。 E.置入泪道引流管:经上、下泪小管置入泪道引流管。 F.复位鼻腔外侧壁-下鼻甲粘膜瓣：充分止血、复位鼻腔外侧壁-下鼻甲粘膜瓣并间断缝合鼻腔粘膜切口和缝合皮肤切口。 图像4 a和b:黄色虚线为中鼻甲腋前上方10毫米至下鼻甲头端鼻底弧形切口（IT:下鼻甲；MT中鼻甲；NS：鼻中隔；UP：钩突）； c:黄线处为下鼻甲骨头端鼻腔外侧壁附着处，解剖鼻泪管； d:双侧黄色虚线内为膜性鼻泪管（IT:下鼻甲；NS：鼻中隔）； e:双侧黄色虚线内为暴露部分泪囊及全程膜性鼻泪管； f:辅助外切口后经鼻切除泪囊、鼻泪管肿瘤（①：泪囊；②：鼻泪管）； g：黄色虚线内为切除后泪囊及鼻泪管术腔（IT：下鼻甲；NS：鼻中隔）； h:切除肿瘤标本； i:置入泪道插管； j:黄色虚线为鼻腔外侧壁已缝合的切口（IT:下鼻甲；MT：中鼻甲；NS:鼻中隔）； K:黄色虚线为外侧径路已缝合切口。      术后病理：上皮呈内翻性生长方式，并见乳头状结构生长，上皮细胞近基底层偶见核分裂象，符合内翻性乳头状瘤。    （HE染色×40） （HE染色×200） 术后复查：鼻窦CT：右侧泪囊区可见低密度影、上颌骨额突术后改变，无残留肿瘤。 术后复查：鼻窦增强MRI:右侧泪囊区未见明显强化。 T1WI水平位 T1WI水平位 T1WI增强水平位 【讨论分析】 泪道是由上下泪点、上下泪小管、泪总管、泪囊和鼻泪管构成。原发性泪道肿物临床上少见，在文献中多为个例报道，Janin（1772年）首次报道，原发性泪道肿物组织病理学类型多样，其中以上皮的乳头状瘤和癌为主[1]。 泪囊是鼻泪管上部扩张部分，根据解剖学特点：原发泪囊肿瘤多发于上皮组织，并易向结膜，鼻泪管等邻近组织侵犯。发生于泪点和泪小管的肿物可导致溢泪，发生于泪囊者临床症状与慢性泪囊炎等常见泪道疾病相似，术前常易误诊。 乳头状瘤是由人类乳头状瘤病毒感染所致一种原发性上皮增殖病变，生长迅速，数月内可形成明显肿物，亦有病程长达数年乃至数十年者。术后复发率高，部分可恶变，故手术切除应彻底，并且严格随访，一旦有复发或恶变的倾向，尽早处理。 手术最小的切除范围应包括泪囊、鼻泪管和上下泪小管, 完整切除泪道对彻底切除病变防止复发甚为重要[2]。Peer等[3]建议对于广泛的和（或）严重的非上皮源性肿瘤要予以广泛的扩大切除，包括泪小管及鼻泪管，但是没有提及此技术的具体细节。 根据本患者主诉、体征、影像学、病理检查诊断鼻腔、泪囊、鼻泪管内翻性乳头状瘤明确，由于肿瘤充满了泪道，侵及鼻腔，因此单一的外路或者内窥镜下手术均无法顺利完整的切除肿物，特别是鼻泪管内的肿瘤。 Timothy 等［4］和黄金峰等[5]认为通过联合外切口开放上部泪道，包括泪小点，泪小管，泪囊及上部鼻泪管联合鼻内镜游离下部鼻泪管是可行的，该术式可充分的解剖分离并能够完整切除病变。 联合手术和外路手术各具优势，外路手术优势在于：直观，尤其适用于病变比较高位，位于泪小管、泪囊和体积较大的肿瘤，但缺点是向下方鼻泪管暴露欠佳。 鼻内镜下手术的优点是镜下操作视野好，内镜放大显示后，术野清晰，观察细微，对于鼻泪管下端及下鼻道的病变处理比较方便，但对于超过泪囊下端的病变操作困难，创伤大。 本病例肿瘤主体部分位于泪囊内，向周围扩张性生长，下方沿着鼻泪管一直长到下鼻道和鼻底部，联合外路+鼻内镜手术操作更加直观地暴露了全泪道、下鼻道和鼻腔，确保了肿瘤切除的完整性。此术式可作为全泪道肿瘤切除的理想选择。 缺陷：本例患者虽然术中置入泪道插管，三个月取出，由于粘膜不能覆盖术后仍有溢泪情况，虽国外有报道行结膜鼻泪管重建术，但国内缺少这样耗材和技术，泪道置管问题值得商榷。 【参考文献】 [1] FlanaganJC,D.Parkr Stokes. Lacrimal sac tumors. Ophthalogy ,1978,8;85:1282-1287. [2] Bonder D,Fischer M J,LevineM R.Squamous cell carcinoma of the lacrimal sac [J]. Ophthalmology,1983,90:1133-1135. [3] Pe\' er JJ, Stefanyszyn M, Hidayat AA. Nonepithelial tumors of the lacrimal sac.American journal of ophthalmology,1994,118:650-658.  [4] Timothy J,Sullivan.Combined External-Endonasal Approach for Complete Excision of the Lacrimal Drainage Apparatu.Ophthalmic Plastic and Ｒeconstructive Surgery,2006,22: 169-172. [5] 黄金峰，陈犇，秦晓怡，等。鼻内镜下经上颌窦泪前隐窝联合经眶径路切除泪道肿瘤一例.中华眼科医学杂志，2013，3（3）：160-162. 病例作者： 武俊男 张福宏 陈枫虹 史剑波 暨南大学附属广东祈福医院 中山大学附属第一医院
"""
        var startTime = CFAbsoluteTimeGetCurrent()
        OpenAI.Tokenizer().encode(str)
        print("1. 执行时间：\(CFAbsoluteTimeGetCurrent() - startTime) 秒")
        
        startTime = CFAbsoluteTimeGetCurrent()
        var split = str.components(separatedBy: ["\n", "，", "。", ";", "；"])
        print("2. 执行时间：\(CFAbsoluteTimeGetCurrent() - startTime) 秒")

        startTime = CFAbsoluteTimeGetCurrent()
        split = split.map({ $0.trimmingCharacters(in: .whitespaces) })
        print("3. 执行时间：\(CFAbsoluteTimeGetCurrent() - startTime) 秒")
        
        startTime = CFAbsoluteTimeGetCurrent()
        split = split.filter({ !$0.isEmpty })
        print("4. 执行时间：\(CFAbsoluteTimeGetCurrent() - startTime) 秒")

        startTime = CFAbsoluteTimeGetCurrent()
        OpenAI.Tokenizer().wordEncode(str)
            .forEach({ print($0.word, $0.token.count) })
        print("5. 执行时间：\(CFAbsoluteTimeGetCurrent() - startTime) 秒")

    }
    
    
}
