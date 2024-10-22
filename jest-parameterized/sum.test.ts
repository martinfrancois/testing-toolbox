import {sum} from "./sum";

it.each`
  a    | b    | expected
  ${1} | ${1} | ${2}
  ${1} | ${2} | ${3}
  ${2} | ${1} | ${3}
`('should return $expected when $a is added to $b', ({a, b, expected}) => {
    expect(sum(a, b)).toBe(expected);
});