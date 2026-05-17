class Problem {
  final String id;
  final String title;
  final String difficulty;
  final List<String> tags;
  final String description;
  final String inputFormat;
  final String outputFormat;
  final List<SampleCase> samples;
  final String hint;
  final int timeLimit; // ms
  final int memoryLimit; // MB

  const Problem({
    required this.id,
    required this.title,
    required this.difficulty,
    this.tags = const [],
    required this.description,
    this.inputFormat = '',
    this.outputFormat = '',
    this.samples = const [],
    this.hint = '',
    this.timeLimit = 1000,
    this.memoryLimit = 256,
  });
}

class SampleCase {
  final String input;
  final String output;
  final String explanation;

  const SampleCase({
    required this.input,
    required this.output,
    this.explanation = '',
  });
}

// ── 预设题目数据 ──

final List<Problem> sampleProblems = [
  Problem(
    id: 'P1001',
    title: 'A+B Problem',
    difficulty: '入门',
    tags: ['入门', '顺序结构'],
    description: '输入两个整数 a, b，输出它们的和。\n\n给定两个整数 a, b (1 ≤ a, b ≤ 1000)，计算 a + b 的值。',
    inputFormat: '一行，两个整数 a, b，以空格分隔。',
    outputFormat: '一行，一个整数，表示 a + b 的值。',
    samples: [
      SampleCase(input: '1 2', output: '3'),
      SampleCase(input: '100 200', output: '300'),
    ],
    timeLimit: 1000,
    memoryLimit: 256,
  ),
  Problem(
    id: 'P1002',
    title: '过河卒',
    difficulty: '普及/提高-',
    tags: ['动态规划', '递推'],
    description:
        '棋盘上 A 点有一个过河卒，需要走到目标 B 点。卒行走的规则：可以向下、或者向右。同时在棋盘上 C 点有一个对方的马，马所在的点和所有跳跃一步可达的点称为对方马的控制点。卒不能通过对方马的控制点。',
    inputFormat: '一行四个正整数，分别表示 B 点坐标和 C 点坐标。',
    outputFormat: '一个整数，表示所有的路径条数。',
    samples: [
      SampleCase(input: '6 6 3 3', output: '6'),
    ],
    hint: '结果可能很大，建议使用 long long 类型。\n\n马的八个控制点：\n(x-2,y-1), (x-2,y+1), (x-1,y-2), (x-1,y+2)\n(x+1,y-2), (x+1,y+2), (x+2,y-1), (x+2,y+1)',
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1003',
    title: '铺地毯',
    difficulty: '普及-',
    tags: ['模拟', '枚举'],
    description:
        '为了准备一个独特的颁奖典礼，组织者在会场铺设了多块矩形地毯。每块地毯覆盖一个矩形区域。给定每块地毯的左下角坐标和它们在 x 轴、y 轴方向的长度，以及一个点 (x, y)，求覆盖该点的最上面一块地毯的编号。',
    inputFormat:
        '第一行一个整数 n，表示地毯的数量。\n接下来 n 行，每行四个整数 a, b, g, k，表示地毯左下角 (a, b) 以及 x 方向长度 g 和 y 方向长度 k。\n最后一行两个整数 x, y，表示查询的点。',
    outputFormat: '一个整数，表示覆盖该点的最上面地毯的编号；若无地毯覆盖则输出 -1。',
    samples: [
      SampleCase(input: '3\n1 0 2 3\n0 2 3 3\n2 1 3 3\n2 2', output: '3'),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1005',
    title: '采药',
    difficulty: '普及/提高-',
    tags: ['动态规划', '01背包'],
    description:
        '辰辰是个天资聪颖的孩子，他的梦想是成为世界上最伟大的医师。为此，他想拜附近最有威望的医师为师。医师为了判断他的资质，给他出了一个难题。\n\n医师把他带到一个到处都是草药的山洞里对他说："孩子，这个山洞里有一些不同的草药，采每一株都需要一些时间，每一株也有它自身的价值。我会给你一段时间，在这段时间里，你可以采到一些草药。如果你是一个聪明的孩子，你应该可以让采到的草药的总价值最大。"',
    inputFormat:
        '第一行有两个整数 T (1 ≤ T ≤ 1000) 和 M (1 ≤ M ≤ 100)，用一个空格隔开，T 代表总共能够用来采药的时间，M 代表山洞里的草药的数目。\n接下来的 M 行每行包括两个在 1 到 100 之间的整数，分别表示采摘某株草药的时间和这株草药的价值。',
    outputFormat: '一个整数，表示在规定的时间内可以采到的草药的最大总价值。',
    samples: [
      SampleCase(
        input: '70 3\n71 100\n69 1\n1 2',
        output: '3',
        explanation: '选择第 2、3 株草药，总时间 70，价值 3。',
      ),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1010',
    title: '幂次方',
    difficulty: '普及-',
    tags: ['递归', '字符串'],
    description:
        '任何一个正整数都可以用 2 的幂次方表示。例如：\n137 = 2^7 + 2^3 + 2^0\n\n同时约定方次用括号来表示，即 a^b 表示为 a(b)。\n\n所以 137 可以表示为：\n2(7) + 2(3) + 2(0)\n\n进一步：\n7 = 2^2 + 2 + 2^0（2^1 用 2 表示）\n3 = 2 + 2^0\n\n所以最后 137 可以表示为：\n2(2(2) + 2 + 2(0)) + 2(2 + 2(0)) + 2(0)',
    inputFormat: '一个正整数 n (n ≤ 20000)。',
    outputFormat: '符合约定的 n 的 0, 2 表示。',
    samples: [
      SampleCase(input: '1315', output: '2(2(2+2(0))+2)+2(2(2+2(0)))+2(2(2)+2(0))+2+2(0)'),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1011',
    title: '车站',
    difficulty: '普及-',
    tags: ['数学', '递推', '模拟'],
    description:
        '火车从始发站（称为第 1 站）开出，在始发站上车的人数为 a，然后到达第 2 站，在第 2 站有人上、下车，但上、下车人数相同，因此在第 2 站开出时车上的人数保持为 a 不变。从第 3 站起（包括第 3 站）上、下车的人数有一定规律：上车的人数都是前两站上车人数之和，下车人数等于上一站上车人数，一直到终点站的前一站（第 n-1 站），都满足此规律。\n\n现给出的条件是：共有 n 个车站，始发站上车的人数为 a，最后一站下车的人数是 m（全部下车）。试问 x 站开出时车上的人数是多少？',
    inputFormat: '四个整数 a, n, m, x。',
    outputFormat: 'x 站开出时车上的人数。',
    samples: [
      SampleCase(input: '1 6 7 3', output: '2'),
      SampleCase(input: '5 7 32 4', output: '13'),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1012',
    title: '拼数',
    difficulty: '普及-',
    tags: ['排序', '字符串', '贪心'],
    description:
        '设有 n 个正整数 (n ≤ 20)，将它们连接成一排，组成一个最大的多位整数。\n\n例如：当 n = 3 时，3 个整数 13, 312, 343 连成的最大整数为 34331213。\n又如：当 n = 4 时，4 个整数 7, 13, 4, 246 连成的最大整数为 7424613。',
    inputFormat: '第一行一个正整数 n。\n第二行 n 个正整数。',
    outputFormat: '一个正整数，表示连接成的最大整数。',
    samples: [
      SampleCase(input: '3\n13 312 343', output: '34331213'),
      SampleCase(input: '4\n7 13 4 246', output: '7424613'),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1028',
    title: '数的计算',
    difficulty: '普及-',
    tags: ['递推', '动态规划'],
    description:
        '我们要求找出具有下列性质数的个数（包含输入的正整数 n）。\n\n先输入一个正整数 n (n ≤ 1000)，然后对此数按照如下方法进行处理：\n1. 不作任何处理；\n2. 在它的左边加上一个自然数，但该自然数不能超过原数的一半；\n3. 加上数后，继续按此规则进行处理，直到不能再加自然数为止。',
    inputFormat: '一个正整数 n。',
    outputFormat: '一个整数，表示满足条件的数的个数。',
    samples: [
      SampleCase(input: '6', output: '6', explanation: '满足条件的数为：6, 16, 26, 126, 36, 136'),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1036',
    title: '选数',
    difficulty: '普及-',
    tags: ['递归', '回溯', '素数判断'],
    description:
        '已知 n 个整数 x₁, x₂, ..., xₙ，以及 1 个整数 k (k < n)。从 n 个整数中任选 k 个整数相加，可分别得到一系列的和。例如当 n = 4, k = 3, 4 个整数分别为 3, 7, 12, 19 时，可得全部的组合与它们的和为：\n3 + 7 + 12 = 22\n3 + 7 + 19 = 29\n7 + 12 + 19 = 38\n3 + 12 + 19 = 34\n\n现在，要求你计算出和为素数共有多少种。',
    inputFormat: '第一行两个正整数 n 和 k。\n第二行 n 个正整数 xᵢ。',
    outputFormat: '一个整数，表示种类数。',
    samples: [
      SampleCase(input: '4 3\n3 7 12 19', output: '1'),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1048',
    title: '采药',
    difficulty: '普及/提高-',
    tags: ['动态规划', '01背包'],
    description:
        '辰辰是个天资聪颖的孩子，他的梦想是成为世界上最伟大的医师。为此，他想拜附近最有威望的医师为师。医师为了判断他的资质，给他出了一个难题。医师把他带到一个到处都是草药的山洞里对他说："孩子，这个山洞里有一些不同的草药，采每一株都需要一些时间，每一株也有它自身的价值。我会给你一段时间，在这段时间里，你可以采到一些草药。如果你是一个聪明的孩子，你应该可以让采到的草药的总价值最大。"',
    inputFormat:
        '第一行有两个整数 T (1 ≤ T ≤ 1000) 和 M (1 ≤ M ≤ 100)，T 代表总共能够用来采药的时间，M 代表山洞里的草药的数目。接下来的 M 行每行包括两个整数，分别表示采摘某株草药的时间和这株草药的价值。',
    outputFormat: '一个整数，表示在规定的时间内可以采到的草药的最大总价值。',
    samples: [
      SampleCase(input: '70 3\n71 100\n69 1\n1 2', output: '3'),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1093',
    title: '奖学金',
    difficulty: '普及-',
    tags: ['排序', '模拟'],
    description:
        '某小学最近得到了一笔赞助，打算拿出其中一部分为学习成绩优秀的前 5 名学生发奖学金。期末，每个学生都有 3 门课的成绩：语文、数学、英语。\n\n先按总分从高到低排序，如果两个学生总分相同，再按语文成绩从高到低排序，如果两个学生总分和语文成绩都相同，那么规定学号小的学生排在前面。',
    inputFormat: '第一行一个整数 n (n ≤ 300)。\n接下来 n 行每行三个整数，分别表示语文、数学、英语成绩。',
    outputFormat: '前 5 名学生的学号和总分，每行一个。',
    samples: [
      SampleCase(
        input: '6\n90 67 80\n87 66 91\n78 89 91\n88 99 77\n67 89 64\n78 89 98',
        output: '6 265\n4 264\n3 258\n2 244\n1 237',
      ),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1101',
    title: '单词方阵',
    difficulty: '普及-',
    tags: ['搜索', 'DFS'],
    description:
        '给一个 n × n 的字母方阵，内可能蕴含多个 "yizhong" 单词。单词在方阵中沿着同一个方向连续摆放，方向可以是 8 个方向中的任意一个。同一个单词摆放时不会改变方向，单词之间可以交叉，因此有可能共用字母。输出时，将不是单词的字母用 * 代替，以突出显示单词。',
    inputFormat: '第一行一个整数 n (n ≤ 100)。\n接下来 n 行，每行 n 个字母。',
    outputFormat: 'n 行，每行 n 个字母，将非单词字母替换为 *。',
    samples: [
      SampleCase(input: '7\naaaaaaa\naaaaaaa\naaaaaaa\naaaaaaa\naaaaaaa\naaaaaaa\naaaaaaa', output: '*******\n*******\n*******\n*******\n*******\n*******\n*******'),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1177',
    title: '快速排序',
    difficulty: '普及-',
    tags: ['排序', '分治'],
    description: '利用快速排序算法将读入的 N 个数从小到大排序后输出。\n\n快速排序是信息学竞赛的必备算法之一。',
    inputFormat: '第一行为一个正整数 N (N ≤ 100000)。\n第二行包含 N 个空格隔开的正整数 aᵢ。',
    outputFormat: '将给定的 N 个数从小到大输出，数之间空格隔开。',
    samples: [
      SampleCase(input: '5\n4 2 4 5 1', output: '1 2 4 4 5'),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1219',
    title: '八皇后',
    difficulty: '普及/提高-',
    tags: ['搜索', '回溯', 'DFS'],
    description:
        '检查一个如下的 6 × 6 的跳棋棋盘，有六个棋子被放置在棋盘上，使得每行、每列有且只有一个，每条对角线（包括两条主对角线的所有平行线）上至多有一个棋子。\n\n请编一个程序找出所有棋子放置的解，并输出前三个解。',
    inputFormat: '一个正整数 n (n ≤ 13)，表示棋盘是 n × n 大小的。',
    outputFormat:
        '前三行每行 n 个整数，表示一种解，相邻两个整数之间用一个空格隔开。\n第四行一个整数，表示总共有多少种解。',
    samples: [
      SampleCase(
        input: '6',
        output: '2 4 6 1 3 5\n3 6 2 5 1 4\n4 1 5 2 6 3\n4',
      ),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1305',
    title: '新二叉树',
    difficulty: '普及-',
    tags: ['树', '遍历', '递归'],
    description:
        '输入一串二叉树，输出其前序遍历。\n\n二叉树用以下方式表示：\n- 第一行一个整数 n，表示二叉树的结点数。\n- 接下来 n 行，每行三个字符，分别表示父节点、左孩子、右孩子。若不存在则用 * 表示。',
    inputFormat: '第一行一个整数 n。\n接下来 n 行，每行三个字符。',
    outputFormat: '一行字符串，表示前序遍历结果。',
    samples: [
      SampleCase(input: '6\nabc\nbdi\ncj*\nd**\ni**\nj**', output: 'abdicj'),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
  Problem(
    id: 'P1308',
    title: '统计单词数',
    difficulty: '普及-',
    tags: ['字符串', '模拟'],
    description:
        '一般的文本编辑器都有查找单词的功能，该功能可以快速定位特定单词在文章中的位置，有的还能统计出特定单词在文章中出现的次数。\n\n现在，请你编程实现这一功能。具体要求是：给定一个单词，请你输出它在给定的文章中出现的次数和第一次出现的位置。注意：匹配单词时，不区分大小写，但要求完全匹配。',
    inputFormat: '第一行一个单词（长度 ≤ 10）。\n第二行一篇文章（长度 ≤ 1,000,000）。',
    outputFormat: '如果找到则输出出现次数和第一次出现的位置（从 0 开始），否则输出 -1。',
    samples: [
      SampleCase(
        input: 'To\nto be or not to be is a question',
        output: '2 0',
      ),
    ],
    timeLimit: 1000,
    memoryLimit: 128,
  ),
];
